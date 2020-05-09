# Initialize the plugin by just calling the classes here
unless Rails.env == 'test'
  CcDeville && Bot::Keep && Workflow::Workflow.workflows && CheckS3 && CheckI18n
end
