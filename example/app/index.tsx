import { View, Text } from 'react-native';
import 'react-native-reanimated';
import {mDocNativeModule} from '@animo-id/expo-mdoc-data-transfer'

export default function Screen() {
  return (
    <View><Text>{mDocNativeModule.hello()}</Text></View>
  );
}
