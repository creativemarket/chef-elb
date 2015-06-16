module Cm
	module Aws
		module Elb
			if new_resource.aws_access_key_id.nil? then
				def elb
				@@elb ||= Fog::AWS::ELB.new(
					:use_iam_profile => true,
					:region => new_resource.region
				)
				end

				def ec2
				@@ec2 ||= Fog::Compute.new(:provider => 'AWS',
					:use_iam_profile => true,
					:region => new_resource.region
				)
				end
			else
				def elb
				@@elb ||= Fog::AWS::ELB.new(
					:use_iam_profile => false,
					:region => new_resource.region,
					:aws_access_key_id => new_resource.aws_access_key_id,
					:aws_secret_access_key => new_resource.aws_secret_access_key
				)
				end

				def ec2
				@@ec2 ||= Fog::Compute.new(:provider => 'AWS',
					:use_iam_profile => false,
					:region => new_resource.region,
					:aws_access_key_id => new_resource.aws_access_key_id,
					:aws_secret_access_key => new_resource.aws_secret_access_key
					)
				end
			end

		def load_balancer_by_name(name)
		elb.describe_load_balancers.body["DescribeLoadBalancersResult"]["LoadBalancerDescriptions"].detect { |lb| lb["LoadBalancerName"] == new_resource.lb_name }
		end

		def policies_for_load_balancer(name)
		elb.describe_load_balancer_policies(name).body["DescribeLoadBalancerPoliciesResult"]["PolicyDescriptions"]
		end

		def availability_zone_for_instances(instances)
		ec2.describe_instances('instance-id' => [*instances]).body['reservationSet'].map { |r| r['instancesSet'] }.flatten.map { |i| i['placement']['availabilityZone'] }
		end

		def subnets_for_instances(instances)
		ec2.describe_instances('instance-id' => [*instances]).body['reservationSet'].map { |r| r['instancesSet'] }.flatten.map { |i| i['networkInterfaces'] }.flatten.map { |n| n['subnetId'] }
		end
	end
end
