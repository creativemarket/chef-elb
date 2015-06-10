module WebsterClay
	module Aws
	module Elb

		def credentials(keys = {})
      keys[:aws_access_key_id] = new_resource.aws_access_key || fetch_iam_creds[:aws_access_key_id]
      keys[:aws_secret_access_key] = new_resource.aws_secret_access_key || fetch_iam_creds[:aws_secret_access_key]
      return keys
    end

		def elb
		@@elb ||= Fog::AWS::ELB.new(
			:aws_access_key_id => credentials[:aws_access_key_id],
			:aws_secret_access_key => credentials[:aws_secret_access_key],
			:region => new_resource.region
    )
		end

		def ec2
		@@ec2 ||= Fog::Compute.new(:provider => 'AWS',
			:aws_access_key_id => credentials[:aws_access_key_id],
			:aws_secret_access_key => credentials[:aws_secret_access_key],
			:region => new_resource.region
		)
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

		def fetch_iam_creds ||= Fog::AWS::CredentialFetcher::ServiceMethods::fetch_credentials(:use_iam_profile => true) end

	end
	end
end
