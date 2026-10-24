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
- **Bandeja**: arquivos guardados no notch (veja abaixo).
- **Clima**: temperatura, condição e as próximas horas, com dados do Open-Meteo.
- **Timer**: atalhos de 1 min a 1 h. A contagem fica ao lado do notch e um alarme toca no fim.

### Bandeja de arquivos

Arraste um arquivo (ou vários) até o notch: a ilha abre na bandeja com duas áreas. Solte à esquerda para guardar, ou à direita para mandar direto por AirDrop. Funciona com arquivos do Finder e com o que outros apps entregam ao arrastar, como fotos do Fotos e anexos do Mail.

Na bandeja, arraste um arquivo para fora para soltá-lo em outro app (ele sai como cópia; o original não muda de lugar), ou use a pilha ao lado para levar todos de uma vez. Clique duas vezes para abrir; com o botão direito há Mostrar no Finder, AirDrop e Tirar da bandeja.

Por padrão a bandeja guarda só onde o arquivo está. Com **Guardar uma cópia** (em Ajustes › Bandeja de arquivos), ela copia para `~/Library/Application Support/Canopy/Tray`, e a cópia é apagada quando sai da bandeja.

Atividades que aparecem ao lado do notch:

- **Música** do Apple Music e do Spotify: capa, faixa, progresso, aleatório, repetir, volume do player e favoritar (só no Apple Music). Clique na capa para abrir o player. Na primeira vez, o macOS pede permissão de Automação para cada player.
- **Reunião**: cinco minutos antes de um evento, com botão Entrar para links do Zoom, Meet, Teams e FaceTime.
- **Bateria**: carregador ligado (com o nível líquido e o tempo até completar), desligado e bateria fraca.
- **Saída de áudio**: AirPods, fones, monitor ou AirPlay quando viram a saída do Mac.
- **Desbloqueio**: o cadeado abre na ilha logo depois de desbloquear o Mac com o Touch ID.
- **Microfone e câmera**: enquanto algum app usa um deles.
- **Volume**: indicador rápido, na cor da música que está tocando.
- **Brilho**: indicador da tela embutida, com um sol que gira conforme o brilho sobe.

Com **Esconder o indicador do macOS** ligado (em Ajustes › Volume e brilho), as teclas de volume e brilho passam pelo Canopy e só a ilha aparece. Option+Shift muda em passos menores e Option sozinho abre os Ajustes do Sistema, como no macOS.

Tudo isso liga e desliga em **Ajustes**, que também controla o Liquid Glass (claro ou escuro), o tamanho da pílula, abrir com o mouse, vibração e esconder em tela cheia ou em gravações de tela.

### Permissões

O macOS pede cada uma na primeira vez que ela é usada: Automação (Apple Music e Spotify), Agenda (ao tocar em Conectar agenda), Localização (só com a localização precisa ligada) e Acessibilidade (para esconder o indicador de volume e brilho do macOS).

Como o app é assinado localmente, o macOS pode esquecer as permissões depois de um build novo. Para Acessibilidade, tire o Canopy da lista com o botão − e adicione de novo. Para não ter que repetir isso, escolha o seu Apple ID em **Team**, na aba Signing & Capabilities do Xcode.

## Desempenho

A meta é ficar abaixo de 100 MB de memória e de 2% de CPU, sem nada atualizando à toa.

- Os módulos esperam avisos do macOS (bateria, volume, brilho, câmera e microfone, agenda, tela cheia) em vez de conferir de tempos em tempos.
- Animações contínuas (equalizador, texto que rola, bateria carregando) são do Core Animation: rodam fora do app, sem o SwiftUI redesenhar nada a cada quadro.
- Relógios usam `AlignedSchedule`, que só atualiza a tela quando o número mostrado muda.

Para medir, `scripts/benchmark.sh` faz o build de Release e mede cada cenário; o CI roda o mesmo script e guarda uma captura da ilha em cada um. No Xcode, o build de Debug com o depurador gasta bem mais do que o app de verdade: para conferir no Monitor de Atividade, mude para Release em Product › Scheme › Edit Scheme › Run › Build Configuration.

## Estrutura

- `Canopy/`: o app (AppKit + SwiftUI): janela do notch, coordenador de atividades, interface e ajustes.
- `CanopyKit/`: pacote Swift com a lógica que não depende de AppKit (estados e páginas da ilha, fila de prioridade, geometria do notch, timer, clima, links de reunião) e os testes dela.

Testes do pacote: `swift test --package-path CanopyKit`.
