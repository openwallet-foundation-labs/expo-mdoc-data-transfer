import { type ConfigPlugin, createRunOncePlugin, withPlugins } from '@expo/config-plugins'

import { withAndroid } from './withAndroid'
import { withIos } from './withIos'

export type Props = {
  ios?: {
    buildStatic?: Array<string>
    bluetoothDescription?: string
  }
}

const withMdocDataTransfer: ConfigPlugin<Props> = (config, props) =>
  withPlugins(config, [withAndroid, [withIos, props]])

export default createRunOncePlugin(withMdocDataTransfer, '@animo-id/mdoc-data-transfer')
