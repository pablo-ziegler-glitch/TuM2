import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

export default function SenalesReportadasScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>SenalesReportadasScreen</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#fff' },
  title: { fontSize: 20, fontWeight: '600' },
});
