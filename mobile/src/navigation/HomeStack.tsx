import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { HomeStackParamList } from './types';
import HomeScreen from '../screens/home/HomeScreen';
import AbiertoAhoraScreen from '../screens/home/AbiertoAhoraScreen';
import FarmaciasDeTurnoScreen from '../screens/home/FarmaciasDeTurnoScreen';
import FichaComercioScreen from '../screens/detail/FichaComercioScreen';
import OnboardingOwnerScreen from '../screens/detail/OnboardingOwnerScreen';

const Stack = createNativeStackNavigator<HomeStackParamList>();

export default function HomeStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: true }}>
      <Stack.Screen
        name="Home"
        component={HomeScreen}
        options={{ title: 'Inicio' }}
      />
      <Stack.Screen
        name="AbiertoAhora"
        component={AbiertoAhoraScreen}
        options={{ title: 'Abierto ahora' }}
      />
      <Stack.Screen
        name="FarmaciasDeTurno"
        component={FarmaciasDeTurnoScreen}
        options={{ title: 'Farmacias de turno' }}
      />
      <Stack.Screen
        name="FichaComercio"
        component={FichaComercioScreen}
        options={{ title: '' }}
      />
      <Stack.Screen
        name="OnboardingOwner"
        component={OnboardingOwnerScreen}
        options={{ title: 'Sumá tu comercio' }}
      />
    </Stack.Navigator>
  );
}
