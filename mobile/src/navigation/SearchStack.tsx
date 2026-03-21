import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { SearchStackParamList } from './types';
import BuscarScreen from '../screens/search/BuscarScreen';
import ResultadosScreen from '../screens/search/ResultadosScreen';
import MapaScreen from '../screens/search/MapaScreen';
import FichaComercioScreen from '../screens/detail/FichaComercioScreen';

const Stack = createNativeStackNavigator<SearchStackParamList>();

export default function SearchStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: true }}>
      <Stack.Screen
        name="Buscar"
        component={BuscarScreen}
        options={{ title: 'Buscar' }}
      />
      <Stack.Screen
        name="Resultados"
        component={ResultadosScreen}
        options={{ title: 'Resultados' }}
      />
      <Stack.Screen
        name="Mapa"
        component={MapaScreen}
        options={{ title: 'Mapa' }}
      />
      <Stack.Screen
        name="FichaComercio"
        component={FichaComercioScreen}
        options={{ title: '' }}
      />
    </Stack.Navigator>
  );
}
