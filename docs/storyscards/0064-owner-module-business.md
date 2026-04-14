# TuM2-0064 — Implementar módulo OWNER (Expansión de negocio)

## Objetivo
El módulo OWNER es el centro operativo del comercio en TuM2. Debe permitir que el dueño vea en segundos el estado actual del comercio, su visibilidad pública, alertas accionables y accesos rápidos a tareas frecuentes para mantener información viva y confiable para vecinos de su zona.

## Contexto
El OWNER administra la presencia operativa del comercio. OWNER-01 Dashboard es la puerta principal post-login para entender qué está bien, qué requiere acción y cuál es la próxima tarea recomendada.

## Problema
Sin dashboard unificado, las tareas quedan dispersas, sin prioridad y con menor mantenimiento operativo. El módulo resuelve esa dispersión y reduce fricción diaria.

## User stories
- Como OWNER, quiero ver si mi comercio está abierto/cerrado/condición especial para entender qué ve el vecino.
- Como OWNER, quiero ver estado de visibilidad (visible/revisión/oculto/suprimido) para actuar rápido.
- Como OWNER, quiero accesos rápidos a horarios, señales operativas, productos y estado del perfil.
- Como OWNER, quiero alertas claras cuando faltan datos o hay bloqueos de publicación.
- Como OWNER, quiero sentir control real sobre cómo aparece mi comercio en TuM2.

## Alcance IN
- OWNER-01 Dashboard como home operativo.
- Resumen de estado actual del comercio.
- Estado de visibilidad/publicación.
- Grilla 2x2 de acciones rápidas.
- Banners/alertas priorizados y orientados a acción.
- Lógica de priorización para lectura inmediata.
- Entrada principal del OWNER autenticado.

## Alcance OUT
- Edición completa de productos (TuM2-0065).
- Edición profunda de perfil/comercio (tarjetas hijas, incluida 0081).
- Rediseño de onboarding/auth/shell.
- Definición técnica completa de persistencia/arquitectura en esta tarjeta.

## Supuestos
- Usuario autenticado.
- Rol OWNER vigente o estado `owner_pending`.
- Puede existir comercio vinculado o caso “sin comercio vinculado”.
- Uso principal en mobile.
- Módulos hijos (horarios, señales, productos) existen o existirán como destinos.

## Dependencias
- TuM2-0054 login/registro.
- TuM2-0053 shell y navegación base.
- Modelo de roles consistente (CUSTOMER/OWNER/estados de revisión).
- Fuente confiable para estado/visibilidad del comercio.

## Arquitectura funcional de producto
Flujo esperado:
1. Splash/auth resuelven identidad y claims.
2. Segmentación OWNER.
3. Entrada a OWNER-01.
4. Lectura rápida: estado del comercio.
5. Alertas priorizadas.
6. Acciones rápidas a módulos operativos.

Criterio: panel simple, directo y accionable; organiza los módulos operativos, no los reemplaza.

## Frontend funcional
Bloques obligatorios:
- Resumen de estado actual.
- Grilla 2x2 de quick actions.
- Banners y alertas (perfil incompleto, revisión pendiente, visibilidad afectada, etc.).

La pantalla debe evitar tono administrativo pesado y priorizar comprensión inmediata.

## Backend funcional
El dashboard debe reflejar estado vigente del comercio con baja latencia percibida. Debe basarse en fuente privada del comercio del OWNER y mantener coherencia con lo visible para vecinos.

## Seguridad de negocio
- Un OWNER solo puede operar su comercio vinculado.
- Sin relación válida rol-usuario-comercio, no debe exponerse el panel operativo.
- Restricción crítica por sensibilidad de datos y capacidad de gestión.

## UX / Microcopy
Lenguaje cercano y territorial TuM2:
- usar “Vecino”, “Comercio”, “Tu zona”.
- mensajes breves, claros y accionables.
- alertas claras, no alarmistas.

## Sincronización documental
Al cierre de fase:
- `CLAUDE.md`: TuM2-0064 en `IN_PROGRESS`.
- Este documento: fuente de negocio sincronizada para la tarjeta.
