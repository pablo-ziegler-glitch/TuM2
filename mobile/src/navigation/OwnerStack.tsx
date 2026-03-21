import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { OwnerStackParamList } from './types';
import PanelComercioScreen from '../screens/owner/PanelComercioScreen';
import EditarPerfilScreen from '../screens/owner/EditarPerfilScreen';
import ProductosScreen from '../screens/owner/ProductosScreen';
import AltaProductoScreen from '../screens/owner/AltaProductoScreen';
import EditarProductoScreen from '../screens/owner/EditarProductoScreen';
import HorariosYSenalesScreen from '../screens/owner/HorariosYSenalesScreen';
import EditarHorariosScreen from '../screens/owner/EditarHorariosScreen';
import TurnosFarmaciaScreen from '../screens/owner/TurnosFarmaciaScreen';
import CalendarioTurnosScreen from '../screens/owner/CalendarioTurnosScreen';
import CargarTurnoScreen from '../screens/owner/CargarTurnoScreen';

const Stack = createNativeStackNavigator<OwnerStackParamList>();

export default function OwnerStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: true }}>
      <Stack.Screen
        name="PanelComercio"
        component={PanelComercioScreen}
        options={{ title: 'Mi comercio' }}
      />
      <Stack.Screen
        name="EditarPerfil"
        component={EditarPerfilScreen}
        options={{ title: 'Editar perfil' }}
      />
      <Stack.Screen
        name="Productos"
        component={ProductosScreen}
        options={{ title: 'Productos' }}
      />
      <Stack.Screen
        name="AltaProducto"
        component={AltaProductoScreen}
        options={{ title: 'Agregar producto' }}
      />
      <Stack.Screen
        name="EditarProducto"
        component={EditarProductoScreen}
        options={{ title: 'Editar producto' }}
      />
      <Stack.Screen
        name="HorariosYSenales"
        component={HorariosYSenalesScreen}
        options={{ title: 'Horarios y señales' }}
      />
      <Stack.Screen
        name="EditarHorarios"
        component={EditarHorariosScreen}
        options={{ title: 'Editar horarios' }}
      />
      <Stack.Screen
        name="TurnosFarmacia"
        component={TurnosFarmaciaScreen}
        options={{ title: 'Turnos farmacia' }}
      />
      <Stack.Screen
        name="CalendarioTurnos"
        component={CalendarioTurnosScreen}
        options={{ title: 'Calendario de turnos' }}
      />
      <Stack.Screen
        name="CargarTurno"
        component={CargarTurnoScreen}
        options={{ title: 'Cargar turno' }}
      />
    </Stack.Navigator>
  );
}
