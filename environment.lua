--[[ ----------------------------------------

    [Main] Environment Settings.

--]] ----------------------------------------

ENV = {

    INSTALLER_EXTNAME = 'lpk',
    INSTALLER_SAFE_DIRS = {
        'plugins/',
        'behavior_packs/',
        'resource_packs/'
    },
    INSTALLER_PACKAGE_CHECK_LIST = {
        'self.json',
        'content'
    },

    INSTALLED_PACKAGE = 'package',
}

return ENV