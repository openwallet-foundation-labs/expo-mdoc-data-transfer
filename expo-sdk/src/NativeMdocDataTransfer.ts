import { requireNativeModule } from 'expo-modules-core'
import type { Spec } from './specs/NativeMdocDataTransfer'

export const requireExpoModule = () => requireNativeModule<Spec>('MdocDataTransfer')
