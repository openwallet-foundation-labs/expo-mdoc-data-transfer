// Learn more https://docs.expo.io/guides/customizing-metro
const { getDefaultConfig } = require('expo/metro-config')

/** @type {import('expo/metro-config').MetroConfig} */
const config = getDefaultConfig(__dirname)

config.resolver.unstable_conditionNames = ['require', 'react-native', 'browser', 'default']
config.resolver.unstable_enablePackageExports = true

module.exports = config
