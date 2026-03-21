// Navigation param types for TuM2

// ─── Auth Stack ──────────────────────────────────────────────────────────────
export type AuthStackParamList = {
  Splash: undefined;
  Onboarding: undefined;
  Login: undefined;
  EmailVerification: { email: string };
};

// ─── Home Stack (Inicio tab) ──────────────────────────────────────────────────
export type HomeStackParamList = {
  Home: undefined;
  AbiertoAhora: undefined;
  FarmaciasDeTurno: undefined;
  FichaComercio: { comercioId: string };
  OnboardingOwner: undefined;
};

// ─── Search Stack (Buscar tab) ────────────────────────────────────────────────
export type SearchStackParamList = {
  Buscar: undefined;
  Resultados: { query?: string; categoria?: string };
  Mapa: { query?: string };
  FichaComercio: { comercioId: string };
};

// ─── Profile Stack (Perfil tab) ───────────────────────────────────────────────
export type ProfileStackParamList = {
  MiPerfil: undefined;
  Configuracion: undefined;
};

// ─── Customer Tabs ────────────────────────────────────────────────────────────
export type CustomerTabsParamList = {
  InicioTab: undefined;
  BuscarTab: undefined;
  PerfilTab: undefined;
};

// ─── Owner Stack (modal) ─────────────────────────────────────────────────────
export type OwnerStackParamList = {
  PanelComercio: undefined;
  EditarPerfil: undefined;
  Productos: undefined;
  AltaProducto: undefined;
  EditarProducto: { productoId: string };
  HorariosYSenales: undefined;
  EditarHorarios: undefined;
  TurnosFarmacia: undefined;
  CalendarioTurnos: undefined;
  CargarTurno: { fecha?: string };
};

// ─── Admin Stack (modal) ─────────────────────────────────────────────────────
export type AdminStackParamList = {
  PanelAdmin: undefined;
  ListadoComercios: undefined;
  DetalleComerciMod: { comercioId: string };
  SenalesReportadas: undefined;
};

// ─── Root (App) Navigator ────────────────────────────────────────────────────
export type RootNavigatorParamList = {
  CustomerTabs: undefined;
  OwnerModal: { screen?: keyof OwnerStackParamList };
  AdminModal: { screen?: keyof AdminStackParamList };
};
