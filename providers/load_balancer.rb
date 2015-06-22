include Cm::Aws::Elb

def load_current_resource

	@current_resource = Chef::Resource::ElbLoadBalancer.new(new_resource.lb_name)
	@current_resource.exists = !!load_balancer_by_name(new_resource.lb_name)

	if @current_resource.exists
		@current_lb = load_balancer_by_name(new_resource.lb_name)
		@current_lb_policies = (@current_lb && policies_for_load_balancer(new_resource.lb_name)) || []
	end

	@current_resource.lb_name(new_resource.lb_name)
	@current_resource.aws_access_key_id(new_resource.aws_access_key_id)
	@current_resource.aws_secret_access_key(new_resource.aws_secret_access_key)
	@current_resource.region(new_resource.region)
	@current_resource.cross_zone_load_balancing(new_resource.cross_zone_load_balancing)
	@current_resource.connection_draining_enable(new_resource.connection_draining_enable)
	@current_resource.connection_draining_timeout(new_resource.connection_draining_timeout)
	@current_resource.listeners(new_resource.listeners)
	@current_resource.timeout(new_resource.timeout)
	@current_resource.health_check(new_resource.health_check)
	@current_resource.policies(new_resource.policies)

	if @current_resource.exists
		@current_resource.availability_zones(@current_lb['AvailabilityZones'])
		@current_resource.subnet_ids(@current_lb['Subnets'])
		@current_resource.instances(@current_lb['Instances'])
	end
	@current_resource.availability_zones || @current_resource.availability_zones([])
	@current_resource.subnet_ids || @current_resource.subnet_ids([])
	@current_resource.instances || @current_resource.instances([])

	if new_resource.instances.nil? && new_resource.search_query
		new_resource.instances(search(:node, new_resource.search_query).map { |n| n['ec2']['instance_id']})
		Chef::Log.info("new_resource.instances = #{new_resource.instances}")
	end

	all_zones = availability_zone_for_instances(new_resource.instances)
	unique_zones = all_zones.compact.uniq

	all_subnets = subnets_for_instances(new_resource.instances)
	unique_subnets = all_subnets.compact.uniq

	if new_resource.availability_zones.nil?
		begin
			new_resource.availability_zones(unique_zones)
		rescue
			Chef::Log.info("No Availability Zones for instances found, and none specified in attributes. Looking for Subnet IDs...")
		end
	end

	if new_resource.subnet_ids.nil?
		begin
			new_resource.subnet_ids(unique_subnets)
		rescue
			Chef::Log.fatal("No Subnet IDs for instances found, and none specified in attributes!")
		end
	end

	# Transform the existing policies into our format.
	if @current_resource.exists
		@current_resource.policies(Hash[@current_lb_policies.map do |policy|
			hash = Hash[policy["PolicyAttributeDescriptions"].map{|attributes| [attributes["AttributeName"], attributes["AttributeValue"]]}]
			hash["Type"] = policy["PolicyTypeName"]
			[policy["PolicyName"], hash]
		end.to_a])
	end
	@current_resource
end

Chef::Log.debug("@current_resource = #{@current_resource}")

action :create do
	if @current_resource.exists
		Chef::Log.info "#{ @new_resource } already exists - nothing to do."
	else

		if new_resource.subnet_ids
			zones = []
			options = { subnet_ids: new_resource.subnet_ids, security_groups: new_resource.security_groups }
			elb.create_load_balancer(zones, new_resource.lb_name, new_resource.listeners, options)
			Chef::Log.info("ELB #{new_resource.lb_name} created in #{new_resource.subnet_ids} and #{new_resource.security_groups}")
		else
			options = { security_groups: new_resource.security_groups }
			elb.create_load_balancer(new_resource.availability_zones, new_resource.lb_name, new_resource.listeners, options)
			Chef::Log.info("ELB #{new_resource.lb_name} created in #{new_resource.availability_zones}")
		end
		new_resource.updated_by_last_action(true)
	end

	node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
	node.save unless Chef::Config.solo

	new_resource.updated_by_last_action(true)

	instances_to_add = new_resource.instances - current_resource.instances
	instances_to_delete = current_resource.instances - new_resource.instances

	instances_to_add.each do |instance_to_add|
		ruby_block "Register instance #{instance_to_add} with ELB #{new_resource.lb_name}" do
			block do
				elb.register_instances_with_load_balancer(instance_to_add, new_resource.lb_name)
				node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
				node.save unless Chef::Config.solo
			end
			action :create
		end
		new_resource.updated_by_last_action(true)
	end

	instances_to_delete.each do |instance_to_delete|
		ruby_block "Deregister instance #{instance_to_delete} from ELB #{new_resource.lb_name}" do
			block do
				elb.deregister_instances_from_load_balancer([instance_to_delete], new_resource.lb_name)
				node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
				node.save unless Chef::Config.solo
			end
			action :create
		end
		new_resource.updated_by_last_action(true)
	end

	if new_resource.subnet_ids
		subnets_to_add = new_resource.subnet_ids - current_resource.subnet_ids
		subnets_to_delete = current_resource.subnet_ids - new_resource.subnet_ids

		subnets_to_add.each do |subnet_to_add|
			ruby_block "Enabling Subnet ID #{subnet_to_add} for ELB #{new_resource.lb_name}" do
				block do
					elb.attach_load_balancer_to_subnets([subnet_to_add], new_resource.lb_name)
					node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
					node.save unless Chef::Config.solo
				end
				action :create
			end
			new_resource.updated_by_last_action(true)
		end

		subnets_to_delete.each do |subnet_to_delete|
			ruby_block "Disabling Subnet ID #{subnet_to_add} for ELB #{new_resource.lb_name}" do
				block do
					elb.detach_load_balancer_from_subnets([subnet_to_delete], new_resource.lb_name)
					node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
					node.save unless Chef::Config.solo
				end
				action :create
			end
			new_resource.updated_by_last_action(true)
		end
	else
		zones_to_add = new_resource.availability_zones - current_resource.availability_zones
		zones_to_delete = current_resource.availability_zones - new_resource.availability_zones

		zones_to_add.each do |zone_to_add|
			ruby_block "Enabling Availability Zone #{zone_to_add} for ELB #{new_resource.lb_name}" do
				block do
					elb.enable_availability_zones_for_load_balancer([zone_to_add], new_resource.lb_name)
					node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
					node.save unless Chef::Config.solo
				end
				action :create
			end
			new_resource.updated_by_last_action(true)
		end

		zones_to_delete.each do |zone_to_delete|
			ruby_block "Disable Availability Zone #{zone_to_delete} for ELB #{new_resource.lb_name}" do
				block do
					elb.disable_availability_zones_for_load_balancer([zone_to_delete], new_resource.lb_name)
					node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
					node.save unless Chef::Config.solo
				end
				action :create
			end
			new_resource.updated_by_last_action(true)
		end
	end

	if new_resource.health_check
		ruby_block "Set health check for ELB #{new_resource.lb_name}" do
			block do
				elb.configure_health_check(new_resource.lb_name, new_resource.health_check)
				node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
				node.save unless Chef::Config.solo
			end
			action :create
		end
		new_resource.updated_by_last_action(true)
	end

	new_resource.policies.each do |name,policy|
		attributes = policy.clone
		attributes.delete(("Type"))

		ruby_block "Create policy '#{name}' for ELB #{new_resource.lb_name}" do
			block do
				elb.create_load_balancer_policy(new_resource.lb_name, name, policy["Type"], attributes)
				node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
				node.save unless Chef::Config.solo
			end
			action :create
		end
		new_resource.updated_by_last_action(true)
	end

	new_resource.listeners.each do |listener|
		if listener["Policies"]
			ruby_block "Set policies for listener on port #{listener['LoadBalancerPort']} for ELB #{new_resource.lb_name}" do
				block do
					elb.set_load_balancer_policies_of_listener(new_resource.lb_name, listener["LoadBalancerPort"], listener["Policies"])
					node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
					node.save unless Chef::Config.solo
				end
				action :create
			end
			new_resource.updated_by_last_action(true)
		end
	end

	if new_resource.connection_draining_enable
		ruby_block "Enable connection draining for ELB #{new_resource.lb_name}" do
			block do
				options = { ConnectionDraining: { Enabled: true, Timeout: new_resource.connection_draining_timeout }}
				elb.modify_load_balancer_attributes(new_resource.lb_name, options)
				node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
				node.save unless Chef::Config.solo
			end
			action :create
		end
		new_resource.updated_by_last_action(true)
	end

	if new_resource.cross_zone_load_balancing
		ruby_block "Enabling cross zone load balancing for ELB #{new_resource.lb_name} & current_resource = #{@current_resource}" do
			block do
				options = { CrossZoneLoadBalancing: { Enabled: true } }
				elb.modify_load_balancer_attributes(new_resource.lb_name, options)
				node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
				node.save unless Chef::Config.solo
			end
			action :create
		end
		new_resource.updated_by_last_action(true)
		Chef::Log.debug("current_resource = #{@current_resource}")
	end
	breakpoint "end of elb_create action block" do
		action :break
	end
end

action :delete do
	ruby_block "Delete ELB #{new_resource.lb_name}" do
		block do
			elb.delete_load_balancer(new_resource.lb_name)
			node.set[:elb][new_resource.lb_name] = nil
			node.save unless Chef::Config.solo
		end
		action :create
		not_if !load_balancer_by_name(new_resource.lb_name)
	end
end
