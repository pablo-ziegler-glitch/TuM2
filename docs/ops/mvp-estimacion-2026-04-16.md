# Estimación y proyección MVP TuM2

Fecha de corte: **2026-04-16**  
Fuente: `git log` + `CLAUDE.md` (backlog maestro)

## Snapshot ejecutivo

- Inicio del repositorio: **2026-03-17**
- Último commit considerado: **2026-04-15**
- Commits totales: **204** (157 sin merges)
- Avance MVP/Fundacional: **48 / 107 = 44.86%**
- En progreso: **1**
- Pendiente total MVP/Fundacional: **59 tarjetas**
- Pendiente por prioridad: **P0=29, P1=22, P2=8**

## Velocidad histórica real

- Promedio global (30 días calendario): **6.8 commits/día**
- Últimos 7 días con actividad: **14.29 commits/día**
- Últimos 14 días con actividad: **8.71 commits/día**
- Días con commits: **20**
- Días sin commits: **10**

## Proyección de cierre MVP

Se proyecta usando tarjetas pendientes MVP/Fundacional (59) y throughput semanal por escenario.

| Escenario | Throughput (tarjetas/semana) | Equivalente diario | Equivalente mensual (4.33 sem) | ETA cierre MVP |
|---|---:|---:|---:|---|
| Optimista | 11.2 | 1.60 | 48.5 | 2026-05-23 |
| Base | 4.0 | 0.57 | 17.3 | 2026-07-28 |
| Conservadora | 3.0 | 0.43 | 13.0 | 2026-09-01 |

## Lectura por épica (MVP/Fundacional)

Bloques con mayor riesgo de timeline por volumen P0 pendiente:

- Épica 18 (Claims): 8 P0 pendientes
- Épicas 4, 9, 11, 12: alta concentración de pendientes estructurales
- Épica 8 (Mobile): 1 en progreso + 5 pendientes

## Archivos de planilla

- `docs/ops/mvp-estimacion-2026-04-16-series.csv`
- `docs/ops/mvp-estimacion-2026-04-16-epicas.csv`
- `docs/ops/mvp-estimacion-2026-04-16-proyeccion.csv`

## Recomendación operativa

Para control ejecutivo, usar el escenario **Base** como compromiso y revisar semanalmente:

1. Tarjetas cerradas reales vs objetivo semanal (4).
2. Variación de pendientes P0.
3. Desvío de ETA (rolling forecast).
