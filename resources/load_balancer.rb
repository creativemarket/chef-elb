actions :create, :delete

attribute :lb_name,               			:kind_of => String,		:name_attribute => true
attribute :aws_access_key,        			:kind_of => String
attribute :aws_secret_access_key, 			:kind_of => String
attribute :aws_session_token, 					:kind_of => String
attribute :region,                			:kind_of => String,		:default => 'us-east-1'
attribute :availability_zones,    			:kind_of => Array
attribute :cross_zone_load_balancing,		:kind_of => Boolean
attribute :connection_draining_enable,	:kind_of => Boolean,	:default => true
attribute :connection_draining_timeout,	:kind_of => Integer,	:default => 300
attribute :subnet_ids,									:kind_of => Array
attribute :listeners,             			:kind_of => Array,		:default => [{"InstancePort" => 80, "Protocol" => "HTTP", "LoadBalancerPort" => 80}]
attribute :instances,             			:kind_of => Array
attribute :search_query,          			:kind_of => String
attribute :timeout,                     	              			:default => 60
attribute :health_check,          			:kind_of => Hash
attribute :policies,              			:kind_of => Hash,			:default => {}
attribute :retries,               			:kind_of => Integer,	:default => 20
