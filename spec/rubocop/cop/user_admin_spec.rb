# frozen_string_literal: true

require 'rubocop_spec_helper'
require_relative '../../../rubocop/cop/user_admin'

RSpec.describe RuboCop::Cop::UserAdmin, feature_category: :system_access do
  let(:msg) do
    'Direct calls to `User#admin?` to determine admin status should be avoided as they will not take into account ' \
      'the policies framework and will ignore Admin Mode if enabled. Please use a policy check with ' \
      '`User#can_admin_all_resources?` or `User#can_read_all_resources?`.'
  end

  it 'flags a method call' do
    expect_offense(<<~RUBY)
      user.admin?
           ^^^^^^ #{msg}
    RUBY
  end

  it 'flags a method call with safe operator' do
    expect_offense(<<~RUBY)
      user&.admin?
            ^^^^^^ #{msg}
    RUBY
  end
end
