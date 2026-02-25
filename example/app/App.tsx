import { mdocDataTransfer, useMdocDataTransferShutdownOnUnmount } from 'expo-mdoc-data-transfer'
import { useState } from 'react'
import { Button, type Permission, PermissionsAndroid, Platform, View } from 'react-native'
import QrCode from 'react-native-qrcode-svg'

const Pad = () => <View style={{ marginBottom: 10 }} />

const PERMISSIONS = [
  'android.permission.ACCESS_FINE_LOCATION',
  'android.permission.BLUETOOTH_CONNECT',
  'android.permission.BLUETOOTH_SCAN',
  'android.permission.BLUETOOTH_ADVERTISE',
  'android.permission.ACCESS_COARSE_LOCATION',
] as const as Permission[]

const requestPermissions = async () => PermissionsAndroid.requestMultiple(PERMISSIONS)

export const App = () => {
  const [qrCode, setQrCode] = useState<string>()

  useMdocDataTransferShutdownOnUnmount()

  const startEngagement = async () => {
    const mdt = mdocDataTransfer.instance()
    mdt.enableNfc()
    const qr = await mdt.startQrEngagement()
    setQrCode(qr)
    await mdt.sendDeviceResponse(new Uint8Array([1, 2, 3]))
    await mdt.waitForDeviceRequest()
    console.log('--- convert device request into a device response ---')
    await mdt.sendDeviceResponse(new Uint8Array())
    mdt.shutdown()
  }

  const shutdown = () => {
    mdocDataTransfer.instance().shutdown()
  }

  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
      {Platform.OS === 'android' && <Button title="request permissions" onPress={requestPermissions} />}
      <Pad />
      <Button title="start engagement" onPress={startEngagement} />
      <Pad />
      <Button title="shutdown" onPress={shutdown} />
      <Pad />
      {qrCode && <QrCode value={qrCode} size={300} />}
    </View>
  )
}
