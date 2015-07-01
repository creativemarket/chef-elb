actions :create, :delete, :dereg_instance
default_action :create

attribute :lb_name,               			kind_of: String,		name_attribute: true
attribute :aws_access_key_id,        		kind_of: String, 		default: nil
attribute :aws_secret_access_key, 			kind_of: String, 		default: nil
attribute :region,                			kind_of: String,		default: 'us-east-1'
attribute :availability_zones,    			kind_of: Array, 		default: []
attribute :cross_zone_load_balancing,		kind_of: [TrueClass, FalseClass],	default: true
attribute :connection_draining_enable,	kind_of: [TrueClass, FalseClass],	default: true
attribute :connection_draining_timeout,	kind_of: Integer,		default: 300
attribute :subnet_ids,									kind_of: Array, 		default: []
attribute :listeners,             			kind_of: Array,			default: [{ 'InstancePort' => 80, 'Protocol' => 'HTTP', 'LoadBalancerPort' => 80 }]
attribute :security_groups,							kind_of: Array,			default: []
attribute :instances,             			kind_of: Array, 		default: []
attribute :search_query,          			kind_of: String,		default: ''
attribute :timeout,                     kind_of: Integer,		default: 60
attribute :health_check,          			kind_of: Hash,			default: {}
attribute :policies,              			kind_of: Hash,			default: {}
attribute :retries,               			kind_of: Integer,		default: 20

attr_accessor :exists
