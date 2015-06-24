include Cm::Aws::Elb

def load_current_resource

	@current_resource = Chef::Resource::ElbLoadBalancer.new(@new_resource.lb_name)
	@current_resource.exists = !!load_balancer_by_name(@new_resource.lb_name)

	if @current_resource.exists
		@current_lb = load_balancer_by_name(@new_resource.lb_name)
		@current_lb_policies = (@current_lb && policies_for_load_balancer(@new_resource.lb_name)) || []
	end

	@current_resource.lb_name(@new_resource.lb_name)
	@current_resource.aws_access_key_id(@new_resource.aws_access_key_id)
	@current_resource.aws_secret_access_key(@new_resource.aws_secret_access_key)
	@current_resource.region(@new_resource.region)
	@current_resource.cross_zone_load_balancing(@new_resource.cross_zone_load_balancing)
	@current_resource.connection_draining_enable(@new_resource.connection_draining_enable)
	@current_resource.connection_draining_timeout(@new_resource.connection_draining_timeout)
	@current_resource.listeners(@new_resource.listeners)
	@current_resource.timeout(@new_resource.timeout)
	@current_resource.health_check(@new_resource.health_check)
	@current_resource.policies(@new_resource.policies)

	if @current_resource.exists
		@current_resource.availability_zones(@current_lb['AvailabilityZones'])
		@current_resource.subnet_ids(@current_lb['Subnets'])
		@current_resource.instances(@current_lb['Instances'])
	end
	@current_resource.availability_zones || @current_resource.availability_zones([])
	@current_resource.subnet_ids || @current_resource.subnet_ids([])
	@current_resource.instances || @current_resource.instances([])

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

action :create do
	if @current_resource.exists
		node.set['elb'][@new_resource.lb_name] = load_balancer_by_name(@new_resource.lb_name)
		Chef::Log.info("node['elb'][@new_resource.lb_name] = #{node['elb'][@new_resource.lb_name]}")
		Chef::Log.info("#{ @new_resource } already exists - Skipping create.")
	else

		all_zones = availability_zone_for_instances(@new_resource.instances)
		unique_zones = all_zones.compact.uniq

		all_subnets = subnets_for_instances(@new_resource.instances)
		unique_subnets = all_subnets.compact.uniq

		if @new_resource.availability_zones.nil?
			begin
				@new_resource.availability_zones(unique_zones)
			rescue
				Chef::Log.info("No Availability Zones for instances found, and none specified in attributes. Looking for Subnet IDs...")
			end
		end

		if @new_resource.subnet_ids.nil?
			begin
				@new_resource.subnet_ids(unique_subnets)
			rescue
				Chef::Log.fatal("No Subnet IDs for instances found, and none specified in attributes!")
			end
		end

		if @new_resource.subnet_ids
			zones = []
			options = { subnet_ids: @new_resource.subnet_ids, security_groups: @new_resource.security_groups }
			elb.create_load_balancer(zones, @new_resource.lb_name, @new_resource.listeners, options)
			node.set['elb'][@new_resource.lb_name] = load_balancer_by_name(@new_resource.lb_name)
			@new_resource.updated_by_last_action(true)
			Chef::Log.info("ELB #{@new_resource.lb_name} created in #{@new_resource.subnet_ids} and #{@new_resource.security_groups}")
		else
			options = { security_groups: @new_resource.security_groups }
			elb.create_load_balancer(@new_resource.availability_zones, @new_resource.lb_name, @new_resource.listeners, options)
			Chef::Log.info("ELB #{@new_resource.lb_name} created in #{@new_resource.availability_zones} and #{@new_resource.security_groups}")
		end
	end

	@new_resource.instances(search(:node, @new_resource.search_query).map { |n| n['ec2']['instance_id']})
	@instances_to_add = @new_resource.instances - @current_resource.instances
	@instances_to_delete = @current_resource.instances - @new_resource.instances

	@instances_to_add.each do |instance_to_add|
		elb.register_instances_with_load_balancer(instance_to_add, @new_resource.lb_name)
		node.set['elb'][@new_resource.lb_name] = load_balancer_by_name(@new_resource.lb_name)
		@new_resource.updated_by_last_action(true)
	end

	@instances_to_delete.each do |instance_to_delete|
		elb.deregister_instances_from_load_balancer([instance_to_delete], @new_resource.lb_name)
		node.set['elb'][@new_resource.lb_name] = load_balancer_by_name(@new_resource.lb_name)
		@new_resource.updated_by_last_action(true)
	end

	if @new_resource.subnet_ids
		subnets_to_add = @new_resource.subnet_ids - @current_resource.subnet_ids
		subnets_to_delete = @current_resource.subnet_ids - @new_resource.subnet_ids

		subnets_to_add.each do |subnet_to_add|
			elb.attach_load_balancer_to_subnets([subnet_to_add], @new_resource.lb_name)
			node.set['elb'][@new_resource.lb_name] = load_balancer_by_name(@new_resource.lb_name)
			@new_resource.updated_by_last_action(true)
		end

		subnets_to_delete.each do |subnet_to_delete|
			elb.detach_load_balancer_from_subnets([subnet_to_delete], @new_resource.lb_name)
			node.set['elb'][@new_resource.lb_name] = load_balancer_by_name(@new_resource.lb_name)
			@new_resource.updated_by_last_action(true)
		end
	else
		zones_to_add = @new_resource.availability_zones - @current_resource.availability_zones
		zones_to_delete = @current_resource.availability_zones - @new_resource.availability_zones

		zones_to_add.each do |zone_to_add|
			elb.enable_availability_zones_for_load_balancer([zone_to_add], @new_resource.lb_name)
			node.set['elb'][@new_resource.lb_name] = load_balancer_by_name(@new_resource.lb_name)
			@new_resource.updated_by_last_action(true)
		end

		zones_to_delete.each do |zone_to_delete|
			elb.disable_availability_zones_for_load_balancer([zone_to_delete], @new_resource.lb_name)
			node.set['elb'][@new_resource.lb_name] = load_balancer_by_name(@new_resource.lb_name)
			@new_resource.updated_by_last_action(true)
		end
	end

	if @new_resource.health_check
		elb.configure_health_check(@new_resource.lb_name, @new_resource.health_check)
		node.set['elb'][@new_resource.lb_name] = load_balancer_by_name(@new_resource.lb_name)
		@new_resource.updated_by_last_action(true)
	end

	@new_resource.policies.each do |name,policy|
		attributes = policy.clone
		attributes.delete(("Type"))
		elb.create_load_balancer_policy(@new_resource.lb_name, name, policy["Type"], attributes)
		node.set['elb'][@new_resource.lb_name] = load_balancer_by_name(@new_resource.lb_name)
		@new_resource.updated_by_last_action(true)
	end

	@new_resource.listeners.each do |listener|
		if listener["Policies"]
			elb.set_load_balancer_policies_of_listener(@new_resource.lb_name, listener["LoadBalancerPort"], listener["Policies"])
			node.set['elb'][@new_resource.lb_name] = load_balancer_by_name(@new_resource.lb_name)
			@new_resource.updated_by_last_action(true)
		end
	end

	if @new_resource.connection_draining_enable
		options = { ConnectionDraining: { Enabled: true, Timeout: @new_resource.connection_draining_timeout }}
		elb.modify_load_balancer_attributes(@new_resource.lb_name, options)
		node.set['elb'][@new_resource.lb_name] = load_balancer_by_name(@new_resource.lb_name)
		@new_resource.updated_by_last_action(true)
	end

	if @new_resource.cross_zone_load_balancing
		options = { CrossZoneLoadBalancing: { Enabled: true } }
		elb.modify_load_balancer_attributes(@new_resource.lb_name, options)
		node.set['elb'][@new_resource.lb_name] = load_balancer_by_name(@new_resource.lb_name)
		@new_resource.updated_by_last_action(true)
	end
	node.save
end

action :delete do
	elb.delete_load_balancer(@new_resource.lb_name)
	node.set['elb'][@new_resource.lb_name] = nil
	@new_resource.updated_by_last_action(true)
	node.save
	not_if !load_balancer_by_name(@new_resource.lb_name)
end
