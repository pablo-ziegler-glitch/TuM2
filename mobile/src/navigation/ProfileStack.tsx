import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { ProfileStackParamList } from './types';
import MiPerfilScreen from '../screens/profile/MiPerfilScreen';
import ConfiguracionScreen from '../screens/profile/ConfiguracionScreen';

const Stack = createNativeStackNavigator<ProfileStackParamList>();

export default function ProfileStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: true }}>
      <Stack.Screen
        name="MiPerfil"
        component={MiPerfilScreen}
        options={{ title: 'Mi perfil' }}
      />
      <Stack.Screen
        name="Configuracion"
        component={ConfiguracionScreen}
        options={{ title: 'Configuración' }}
      />
    </Stack.Navigator>
  );
}
