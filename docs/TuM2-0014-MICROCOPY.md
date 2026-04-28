# TuM2-0014 — Definir tono de microcopy para el producto TuM2

## Guía de Microcopy para TuM2 – MVP Fase 3

### 1. Introducción

TuM2 es la capa digital del comercio de cercanía. La app conecta a vecinos con los comercios de su barrio, permitiéndoles encontrar fácilmente servicios de confianza en su área. La filosofía de la marca se basa en la cercanía territorial y la utilidad inmediata, resumida en el lema **“lo que necesitás, en tu zona”**. El tono que el equipo quiere reflejar es cercano, útil, claro, cotidiano y confiable.

Esta guía documenta un tono coherente para las pantallas del MVP, define un glosario de términos y propone microcopy específico para cada estado de la app.

### 2. Guía de Estilo Rápida

#### 2.1 Cercano pero no informal

El objetivo es hablarle al vecino “de tú a tú” sin sonar irreverente. Estudios de UX recomiendan usar lenguaje conversacional pero evitar la jerga o los chistes internos: UX Tools subraya que la microcopy debe usar lenguaje natural, con palabras familiares y una entonación relajada. Yellowball añade que la voz amable no debe volverse casual o jocosa; un tono neutral y calmado mantiene al usuario enfocado.

**Principios para la voz cercana**

- Hablar en segunda persona (“vos”/“tu”). Utilizar pronombres hace que el mensaje parezca una conversación íntima.
- Lenguaje cotidiano, sin tecnicismos. Es mejor decir “Buscá tu farmacia más cercana” que “Seleccione una entidad prestadora de servicios farmacéuticos”.
- Empatía y anticipación de dudas. La microcopy debe explicar claramente el porqué de la solicitud: un campo de “Teléfono” puede indicar que se usa para coordinar el pedido. Esto reduce la confusión y el estrés.
- Corto y directo. “Less is more” es un principio del UX writing. Evitar frases largas; preferir verbos de acción al inicio.
- Positividad en momentos difíciles. Frente a errores, usar un tono amigable y ofrecer soluciones. Evitar culpar al usuario; en vez de “contraseña incorrecta”, decir “esa contraseña no parece correcta, volvé a intentarlo”.

#### 2.2 Profesional pero no frío

Queremos transmitir fiabilidad y exactitud sin parecer distantes. La microcopy profesional se apoya en la claridad y la transparencia:

- Claridad de la información. La microcopy debería educar e informar al usuario. Por ejemplo, explicar la finalidad de solicitar la ubicación (para mostrar comercios cercanos) ayuda a generar confianza.
- Tono neutral y respetuoso. La amabilidad no debe sonar como un chiste; el lenguaje debe ser calmado y neutral.
- Coherencia terminológica. Elegir una única palabra para cada concepto crea profesionalidad y evita confusión.
- Soporte inmediato. Proporcionar indicaciones claras para solucionar problemas en vez de mostrar códigos de error técnicos.

### 3. Diccionario de términos

Para un producto de cercanía es crítico usar términos comprensibles por cualquier vecino en Argentina. Tras analizar sinónimos, se propone estandarizar los siguientes términos:

| Concepto | Término elegido | Justificación |
|---|---|---|
| Pequeños negocios | Comercio | Es la palabra más neutra y amplia para referirse a cualquier tipo de negocio físico. “Local” enfatiza el espacio físico y puede confundirse con “mi barrio”; “tienda” se asocia a e-commerce o indumentaria. “Comercio” también aparece en el nombre de la base de datos `merchant_public`, lo que alinea terminología técnica y de interfaz. |
| Usuario | Vecino | Refuerza el sentido de comunidad y cercanía, evitando el término genérico “usuario”. |
| Zona | Tu zona | La app se centra en el barrio o radio cercano; “tu zona” refuerza la relación personal con el territorio. |
| Estado operativo | Abierto ahora, Cerrado, Horario verificado | Evitar tecnicismos como “status”; usar frases que reflejen la realidad actual. |
| Comunidad | Comunidad | Se mantiene para aludir a la red de vecinos que aportan información. |

### 4. Microcopy para cada pantalla del MVP

#### 4.1 Pantalla Home

Placeholder en la barra de búsqueda. Los placeholders deben ser ejemplos concretos de lo que la gente suele buscar, usando preguntas en tono cercano. Usar una pregunta en lugar de un comando (“¿Buscás…?”) invita al usuario a participar.

- Ejemplo 1: ¿Buscás una farmacia?
- Ejemplo 2: ¿Necesitás una verdulería?
- Ejemplo 3: ¿Querés pedir comida?

La función debería rotar aleatoriamente entre las diferentes categorías populares para inspirar búsquedas.

#### 4.2 Loading States

Durante la carga de datos, la microcopy debe tranquilizar y reforzar la proximidad. La investigación muestra que la microcopy que anticipa preocupaciones y explica lo que ocurre reduce la incertidumbre.

- Mapeando tu zona…
- Buscando comercios cerca de vos…
- Consultando horarios actualizados…
- Recopilando datos de tu comunidad…

Estos mensajes informan al usuario de la acción en curso y destacan la utilidad inmediata (“tu zona”).

#### 4.3 Empty States (sin resultados)

Cuando no hay resultados para una búsqueda o categoría, es crucial mantener la empatía y promover la participación comunitaria. La microcopy debe explicar el motivo, orientar hacia una acción y mantener un tono positivo.

- Mensaje principal: Todavía no tenemos datos de ese comercio en tu zona.
- Sugerencia: ¡Sé el primero en sumarlo! Compartí la información de tu comercio de confianza para ayudar a tus vecinos.
- Llamado a la acción: Botón “Agregar nuevo comercio”.

Para búsquedas sin resultados: No encontramos coincidencias para “{término}”. Probá cambiando de categoría o sumando uno nuevo.

#### 4.4 Badges operativos

Los badges deben ser concisos, informativos y fáciles de reconocer. Recordemos que las etiquetas deben empezar con verbos o palabras activas.

| Badge | Microcopy | Uso |
|---|---|---|
| Abierto ahora | Abierto ahora | Para comercios en horario de atención. |
| Cerrado | Cerrado | Cuando el comercio no atiende al público en ese momento. |
| Abre a las … | Abre a las 9 h (hora variable) | Para indicar hora próxima de apertura. |
| Farmacia de turno | Farmacia de turno | Para farmacias con horario ampliado/guardia. |
| Horario verificado | Horario verificado | Indica que la comunidad confirmó el horario recientemente. |
| Dato referencial | Horario referencial | Si el horario proviene de fuentes no verificadas, aclarar la naturaleza comunitaria. |

#### 4.5 Mensajes de error

Los mensajes deben usar lenguaje cotidiano y ofrecer soluciones. Según las buenas prácticas, es clave evitar palabras negativas o técnicas y mostrar empatía.

- **Problemas de conexión**
  - Mensaje: No pudimos conectarnos. Verificá tu conexión a internet y volvé a intentar.
  - Justificación: Informa de forma clara qué ocurrió y orienta sobre cómo resolverlo.
- **GPS desactivado o sin permisos**
  - Mensaje: Necesitamos tu ubicación para mostrarte comercios cerca. Activá el GPS o ingresá tu dirección manualmente.
  - Justificación: Explica la finalidad de la ubicación (información y utilidad) y ofrece alternativa.
- **Carga fallida de datos**
  - Mensaje: Ups, algo salió mal al cargar los datos. Probá nuevamente en unos segundos.
  - Justificación: Evita culpar al usuario y transmite que el problema es temporal.
- **Campos obligatorios vacíos**
  - Mensaje: Este campo es obligatorio. Completalo para continuar.
  - Justificación: Al usar “este” personalizamos la indicación; se mantiene clara y sin tono acusatorio.

En todos los casos, si el error persiste, un enlace a “Ayuda” o “Contactanos” debe estar disponible.

### 5. Criterios de aceptación (BDD)

Para validar que el tono de voz y la microcopy cumplen con la guía, se pueden redactar escenarios en formato Given/When/Then (Gherkin). Los siguientes ejemplos se centran en el flujo de registro de un nuevo vecino:

- **Escenario: Mensajes claros en el formulario de registro**
  - Given el vecino accede al formulario de registro por primera vez,
  - When introduce su email y crea una contraseña,
  - Then las etiquetas de los campos deben usar un lenguaje cotidiano (“Correo electrónico”, “Contraseña”) y los mensajes de ayuda deben indicar claramente el requisito (ej.: Tu contraseña debe tener al menos 8 caracteres), sin tecnicismos.

- **Escenario: Manejo de errores de validación**
  - Given el vecino deja un campo obligatorio vacío o introduce datos inválidos,
  - When intenta enviar el formulario,
  - Then la app debe mostrar un mensaje en tono cercano y profesional (Este campo es obligatorio. Completalo para continuar), explicar por qué no se puede continuar y guiar sobre cómo corregirlo.

- **Escenario: Confirmación de registro exitoso**
  - Given el vecino completa correctamente el registro,
  - When envía el formulario,
  - Then la app debe mostrar una confirmación positiva (¡Listo! Ya sos parte de la comunidad.) que refuerce la pertenencia, seguida de una breve explicación de los próximos pasos (ej.: Ahora podés buscar comercios en tu zona o agregar uno nuevo).

- **Escenario: Solicitud de permisos de ubicación**
  - Given un vecino que aún no otorgó permisos de ubicación,
  - When la app necesita acceder a su ubicación para mostrar resultados,
  - Then se debe mostrar un cuadro de diálogo con lenguaje transparente (Necesitamos tu ubicación para mostrarte comercios cercanos), explicando la ventaja y permitiendo optar por ingresar una dirección manual si lo prefiere.

- **Escenario: Mensaje de error técnico durante el registro**
  - Given ocurre un fallo técnico inesperado mientras se procesa el registro,
  - When el sistema detecta este error,
  - Then se debe mostrar un mensaje amigable (Ups, algo salió mal. Intentá nuevamente en unos segundos) que no culpe al usuario y ofrezca un botón de reintento.

### 6. Consideraciones técnicas y de usabilidad

- Tiempo de respuesta (&lt; 5 segundos): la app debe servir datos desde `merchant_public` en menos de cinco segundos. La microcopy de loading states debe cubrir breves períodos de espera sin crear ansiedad.
- Coherencia en la navegación core: los términos principales (Buscar, Mapa, Categorías, Perfil, Mi comercio) no se modifican para evitar confusión. La personalidad de la marca se aplica en capas narrativas como onboarding, estados vacíos y mensajes de error.
- Escalabilidad: esta guía debe considerarse un artefacto vivo. A medida que se agreguen nuevas pantallas o features, cualquier nueva microcopy debe alinearse con estos principios y reutilizar términos del diccionario.

### 7. Conclusión

Una microcopy bien diseñada no es solo estética; es una herramienta de conversión y confianza. Al definir un tono cercano pero profesional y estandarizar los términos ahora, TuM2 evitará inconsistencias y reducirá la necesidad de improvisaciones futuras. Las frases propuestas cumplen con las mejores prácticas de UX writing: hablan con claridad, anticipan inquietudes, usan lenguaje natural y brindan apoyo. Estas pautas ayudarán a que cada vecino se sienta acompañado desde el primer uso de la app.

## OWNER-01 — Horarios y Avisos de hoy

En OWNER-01, el lenguaje visible para el dueño separa operación habitual de cambios temporales.

### Horarios

Representa la atención normal del comercio (estable y rutinaria): cuándo atendés normalmente.

Microcopy canónico:
- Título: "Horarios"
- Subtítulo: "Definí cuándo atendés normalmente."
- CTA: "Editar horarios"

### Avisos de hoy

Representa cambios temporales informados por el dueño para el día en curso.  
No usar "señales operativas" como label principal en UI OWNER.

Microcopy canónico sin aviso activo:
- Título: "Avisos de hoy"
- Subtítulo: "Informá si cerrás, abrís más tarde o estás de vacaciones."
- CTA: "Avisar cambio"

Microcopy canónico con aviso activo:
- Mostrar tipo visible:
  - "De vacaciones"
  - "Cerrado temporalmente"
  - "Abre más tarde"
- Mostrar acción clara: "Desactivar aviso" o entrada equivalente a gestión del aviso.

### Estado operativo visible

OWNER-01 debe mostrar estado y fuente:
- "Fuente: horario habitual" para estado derivado de horarios.
- "Fuente: aviso activo" para estado derivado de aviso temporal.
- "Fuente: horarios no disponibles" cuando no se puede determinar abierto/cerrado.

No mostrar nombres técnicos de colecciones, campos, enums ni reglas internas en UI.
