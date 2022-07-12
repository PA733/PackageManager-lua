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
    INSTALLER_WHITELIST = {
        '8cb3f98e-db18-4b84-85ca-cbc607cee32f'
    },
    INSTALLER_PACKAGE_CHECK_LIST = {
        'self.json',
        'content'
    },

    INSTALLED_PACKAGE = 'package',
}

return ENV