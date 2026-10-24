# Canopy

Um Dynamic Island para o notch do MacBook, escrito em Swift para macOS.

## Como rodar

1. Instale o Xcode 26 ou mais novo pela App Store.
2. Abra `Canopy.xcodeproj` no Xcode.
3. Escolha o esquema **Canopy** e o destino **My Mac**, e aperte ⌘R.

O app não tem ícone no Dock. Ele aparece como uma cápsula na barra de menus e como uma ilha preta no notch. Passe o mouse no notch para abrir; clique para mantê-la aberta; clique fora para fechar. Em telas sem notch, a ilha aparece como uma pílula no topo da tela.

Para testar o estado compacto, ligue **Atividade de teste** no menu da barra.

## O que a ilha mostra

A ilha aberta tem páginas. As abas ficam no topo, à esquerda do notch. Para trocar, clique numa aba ou arraste dois dedos para os lados no trackpad.

- **Agora**: a atividade da frente, como a música ou um timer correndo.
- **Início**: saudação, hora, data e os próximos eventos da agenda.
- **Clima**: temperatura, condição e as próximas horas, com dados do Open-Meteo.
- **Timer**: atalhos de 1 min a 1 h. A contagem fica ao lado do notch e um alarme toca no fim.

Atividades que aparecem ao lado do notch:

- **Música** do Apple Music e do Spotify: capa, faixa, progresso, aleatório, repetir, volume do player e favoritar (só no Apple Music). Clique na capa para abrir o player. Na primeira vez, o macOS pede permissão de Automação para cada player.
- **Reunião**: cinco minutos antes de um evento, com botão Entrar para links do Zoom, Meet, Teams e FaceTime.
- **Bateria**: carregador ligado (com o nível líquido e o tempo até completar), desligado e bateria fraca.
- **Saída de áudio**: AirPods, fones, monitor ou AirPlay quando viram a saída do Mac.
- **Desbloqueio**: o cadeado abre na ilha logo depois de desbloquear o Mac com o Touch ID.
- **Microfone e câmera**: enquanto algum app usa um deles.
- **Volume**: indicador rápido, na cor da música que está tocando.

Tudo isso liga e desliga em **Ajustes**, que também controla o Liquid Glass (claro ou escuro), o tamanho da pílula, abrir com o mouse, vibração e esconder em tela cheia ou em gravações de tela.

### Permissões

O macOS pede cada uma na primeira vez que ela é usada: Automação (Apple Music e Spotify), Agenda (ao tocar em Conectar agenda) e Localização (só com a localização precisa ligada). Como o app é assinado localmente, o macOS pode pedir de novo depois de um build novo.

## Estrutura

- `Canopy/`: o app (AppKit + SwiftUI): janela do notch, coordenador de atividades, interface e ajustes.
- `CanopyKit/`: pacote Swift com a lógica que não depende de AppKit (estados e páginas da ilha, fila de prioridade, geometria do notch, timer, clima, links de reunião) e os testes dela.

Testes do pacote: `swift test --package-path CanopyKit`.
