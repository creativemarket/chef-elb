module Cm
	module Aws
		module Elb
			def elb
				if new_resource.aws_access_key_id.nil?
					@@elb ||= Fog::AWS::ELB.new(
						:use_iam_profile => true,
						:region => new_resource.region
					)
				else
					@@elb ||= Fog::AWS::ELB.new(
						:use_iam_profile => false,
						:region => new_resource.region,
						:aws_access_key_id => new_resource.aws_access_key_id,
						:aws_secret_access_key => new_resource.aws_secret_access_key
					)
				end
			end

			def ec2
				if new_resource.aws_access_key_id.nil?
					@@ec2 ||= Fog::Compute.new(:provider => 'AWS',
						:use_iam_profile => true,
						:region => new_resource.region
					)
				else
					@@ec2 ||= Fog::Compute.new(:provider => 'AWS',
						:use_iam_profile => false,
						:region => new_resource.region,
						:aws_access_key_id => new_resource.aws_access_key_id,
						:aws_secret_access_key => new_resource.aws_secret_access_key
					)
				end
			end


			def load_balancer_by_name(name)
				options = { LoadBalancerNames: [name] }
				elb.describe_load_balancers(options).body["DescribeLoadBalancersResult"]["LoadBalancerDescriptions"]
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
end
