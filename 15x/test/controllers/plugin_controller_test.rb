require 'test_helper'

class PluginControllerTest < ActionController::TestCase
  test "should get about" do
    get :about
    assert_response :success
  end

  test "should get install" do
    get :install
    assert_response :success
  end

end
