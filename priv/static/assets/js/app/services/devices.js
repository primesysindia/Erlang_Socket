device_setup_app.service('Devices', function ($resource) {

    return $resource('/api/devices');
});