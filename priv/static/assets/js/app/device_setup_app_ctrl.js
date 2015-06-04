device_setup_app.controller('device_setup_app_ctrl', ['$scope', 'Devices', function($scope, Devices){
    $scope.title = "From Ng.";

    console.log(Devices.query());

}]);