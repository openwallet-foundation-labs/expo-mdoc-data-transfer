import {
  AndroidConfig,
  type ConfigPlugin,
  withAndroidManifest,
  withAppBuildGradle,
  withPlugins,
} from '@expo/config-plugins'

type InnerManifest = AndroidConfig.Manifest.AndroidManifest['manifest']

type ManifestPermission = InnerManifest['permission']

type ExtraItems = {
  'tools:targetApi'?: string
  'android:usesPermissionFlags'?: string
  'android:maxSdkVersion'?: string
}

type ManifestUsesPermissionWithExtraItems = {
  $: AndroidConfig.Manifest.ManifestUsesPermission['$'] & ExtraItems
}

type AndroidManifest = {
  manifest: InnerManifest & {
    permission?: ManifestPermission
    'uses-permission'?: ManifestUsesPermissionWithExtraItems[]
    'uses-feature'?: InnerManifest['uses-feature']
  }
}

const withBleAndroidManifest: ConfigPlugin = (config) =>
  withAndroidManifest(config, (config) => {
    config.modResults = addScanAndAdvertisePermissionToManifest(config.modResults)
    config.modResults = addConnectPermissionToManifest(config.modResults)
    config.modResults = addLegacyBlePermissionToManifest(config.modResults)

    return config
  })

function addLegacyBlePermissionToManifest(androidManifest: AndroidManifest) {
  if (!Array.isArray(androidManifest.manifest['uses-permission'])) {
    androidManifest.manifest['uses-permission'] = []
  }

  if (
    !androidManifest.manifest['uses-permission'].find(
      (item) => item.$['android:name'] === 'android.permission.BLUETOOTH'
    )
  ) {
    AndroidConfig.Manifest.ensureToolsAvailable(androidManifest)
    androidManifest.manifest['uses-permission']?.push({
      $: {
        'android:name': 'android.permission.BLUETOOTH',
        'android:maxSdkVersion': '30',
      },
    })
    androidManifest.manifest['uses-permission']?.push({
      $: {
        'android:name': 'android.permission.BLUETOOTH_ADMIN',
        'android:maxSdkVersion': '30',
      },
    })
  }
  return androidManifest
}

function addScanAndAdvertisePermissionToManifest(androidManifest: AndroidManifest) {
  if (!Array.isArray(androidManifest.manifest['uses-permission'])) {
    androidManifest.manifest['uses-permission'] = []
  }

  if (
    !androidManifest.manifest['uses-permission'].find(
      (item) => item.$['android:name'] === 'android.permission.BLUETOOTH_SCAN'
    )
  ) {
    AndroidConfig.Manifest.ensureToolsAvailable(androidManifest)
    androidManifest.manifest['uses-permission']?.push({
      $: {
        'android:name': 'android.permission.BLUETOOTH_SCAN',
        'android:usesPermissionFlags': 'neverForLocation',
        'tools:targetApi': '31',
      },
    })
    androidManifest.manifest['uses-permission']?.push({
      $: {
        'android:name': 'android.permission.BLUETOOTH_ADVERTISE',
        'tools:targetApi': '31',
      },
    })
  }
  return androidManifest
}

function addConnectPermissionToManifest(androidManifest: AndroidManifest) {
  if (!Array.isArray(androidManifest.manifest['uses-permission'])) {
    androidManifest.manifest['uses-permission'] = []
  }

  if (
    !androidManifest.manifest['uses-permission'].find(
      (item) => item.$['android:name'] === 'android.permission.BLUETOOTH_CONNECT'
    )
  ) {
    AndroidConfig.Manifest.ensureToolsAvailable(androidManifest)
    androidManifest.manifest['uses-permission']?.push({
      $: {
        'android:name': 'android.permission.BLUETOOTH_CONNECT',
      },
    })
  }
  return androidManifest
}

const withAndroidExcludeBcProv: ConfigPlugin = (expoConfig) =>
  withAppBuildGradle(expoConfig, (c) => {
    if (c.modResults.contents.includes("all*.exclude module: 'bcprov-jdk15to18'")) return c
    c.modResults.contents += `android { configurations { all*.exclude module: 'bcprov-jdk15to18' } }`
    return c
  })

const withAndroidNfcProperties: ConfigPlugin = (expoConfig) =>
  withAndroidManifest(expoConfig, (c) => {
    const androidManifest = c.modResults.manifest

    if (!androidManifest['uses-permission']?.some((p) => p.$['android:name'] === 'android.permission.NFC')) {
      androidManifest['uses-permission']?.push({
        $: {
          'android:name': 'android.permission.NFC',
        },
      })
    }

    for (const app of androidManifest.application ?? []) {
      if (app.service?.some((s) => s.$['android:name'] === 'id.animo.mdocdatatransfer.NfcEngagementServiceImpl'))
        continue
      app.service ??= []
      app.service.push({
        $: {
          'android:exported': 'true',
          'android:name': 'id.animo.mdocdatatransfer.NfcEngagementServiceImpl',
          'android:permission': 'android.permission.BIND_NFC_SERVICE',
        },
        'intent-filter': [
          {
            action: [
              {
                $: {
                  'android:name': 'android.nfc.action.NDEF_DISCOVERED',
                },
              },
              {
                $: {
                  'android:name': 'android.nfc.cardemulation.action.HOST_APDU_SERVICE',
                },
              },
            ],
          },
        ],
        // @ts-expect-error
        'meta-data': {
          $: {
            'android:name': 'android.nfc.cardemulation.host_apdu_service',
            'android:resource': '@xml/nfc_engagement_apdu_service',
          },
        },
      })
    }

    return c
  })

export const withAndroid: ConfigPlugin = (config) =>
  withPlugins(config, [
    (c) => AndroidConfig.Permissions.withPermissions(c, ['android.permission.BLUETOOTH_CONNECT']),
    withBleAndroidManifest,
    withAndroidExcludeBcProv,
    withAndroidNfcProperties,
  ])
