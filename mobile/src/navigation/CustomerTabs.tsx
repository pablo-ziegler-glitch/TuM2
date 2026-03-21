import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { CustomerTabsParamList } from './types';
import HomeStack from './HomeStack';
import SearchStack from './SearchStack';
import ProfileStack from './ProfileStack';

const Tab = createBottomTabNavigator<CustomerTabsParamList>();

export default function CustomerTabs() {
  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: '#0070CC',
        tabBarInactiveTintColor: '#8E8E93',
      }}
    >
      <Tab.Screen
        name="InicioTab"
        component={HomeStack}
        options={{ title: 'Inicio' }}
      />
      <Tab.Screen
        name="BuscarTab"
        component={SearchStack}
        options={{ title: 'Buscar' }}
      />
      <Tab.Screen
        name="PerfilTab"
        component={ProfileStack}
        options={{ title: 'Perfil' }}
      />
    </Tab.Navigator>
  );
}
