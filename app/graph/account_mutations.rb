module AccountMutations

  update_fields = {
    refresh_account: 'int'
  }

  Create, Update, Destroy = Mutations::GraphqlCrudOperations.define_crud_operations('account', {}, update_fields)
end
