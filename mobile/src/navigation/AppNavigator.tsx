import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { RootNavigatorParamList } from './types';
import CustomerTabs from './CustomerTabs';
import OwnerStack from './OwnerStack';
import AdminStack from './AdminStack';

const Stack = createNativeStackNavigator<RootNavigatorParamList>();

export default function AppNavigator() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      {/* Main customer experience */}
      <Stack.Screen name="CustomerTabs" component={CustomerTabs} />

      {/* Owner module - presented as modal */}
      <Stack.Screen
        name="OwnerModal"
        component={OwnerStack}
        options={{ presentation: 'modal' }}
      />

      {/* Admin module - presented as modal */}
      <Stack.Screen
        name="AdminModal"
        component={AdminStack}
        options={{ presentation: 'modal' }}
      />
    </Stack.Navigator>
  );
}
