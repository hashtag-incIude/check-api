# Initialize the plugin by just calling the classes here
begin
  ActiveRecord::Base.connection
  CcDeville && Bot::Keep && Workflow::Workflow.workflows && CheckS3 && CheckI18n
rescue
  # Database doesn't exist
end
