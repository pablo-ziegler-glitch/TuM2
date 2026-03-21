import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { AdminStackParamList } from './types';
import PanelAdminScreen from '../screens/admin/PanelAdminScreen';
import ListadoComercioslModScreen from '../screens/admin/ListadoComercioslModScreen';
import DetalleComerciomModScreen from '../screens/admin/DetalleComerciomModScreen';
import SenalesReportadasScreen from '../screens/admin/SenalesReportadasScreen';

const Stack = createNativeStackNavigator<AdminStackParamList>();

export default function AdminStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: true }}>
      <Stack.Screen
        name="PanelAdmin"
        component={PanelAdminScreen}
        options={{ title: 'Panel Admin' }}
      />
      <Stack.Screen
        name="ListadoComercios"
        component={ListadoComercioslModScreen}
        options={{ title: 'Comercios' }}
      />
      <Stack.Screen
        name="DetalleComerciMod"
        component={DetalleComerciomModScreen}
        options={{ title: 'Detalle comercio' }}
      />
      <Stack.Screen
        name="SenalesReportadas"
        component={SenalesReportadasScreen}
        options={{ title: 'Señales reportadas' }}
      />
    </Stack.Navigator>
  );
}
