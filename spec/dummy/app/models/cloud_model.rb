class CloudModel < OceanDynamo::Table

dynamo_schema(:uuid, create: true, table_name_suffix: Api.basename_suffix) do
    attribute :credentials,          :string,      default: "blah"
    attribute :token,                :string
    attribute :steps,                :serialized,  default: []
    attribute :max_seconds_in_queue, :integer,     default: 1.day
    attribute :default_poison_limit, :integer,     default: 5
    attribute :default_step_time,    :integer,     default: 30
    attribute :created_by,           :string
    attribute :updated_by,           :string
    attribute :destroy_at,           :datetime
    attribute :started_at,           :datetime
    attribute :last_completed_step,  :integer
    attribute :succeeded,            :boolean,     default: true
    attribute :failed,               :boolean,     default: false
    attribute :poison,               :boolean,     default: false
    attribute :finished_at,          :datetime
    attribute :gratuitous_float,     :float,       default: lambda { rand }
    attribute :zalagadoola,          :string,      default: "Menchikaboola"
    attribute :list,                 :string,      default: ["1", "2", "3"]
    attribute :int,                  :integer,     default: 1066
  end


  validates_each :steps do |record, attr, value|
    record.errors.add(attr, 'must be an Array') unless value.is_a?(Array)
  end 

end
