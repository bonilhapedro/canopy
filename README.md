# Canopy

Um Dynamic Island para o notch do MacBook, escrito em Swift para macOS.

## Como rodar

1. Instale o Xcode 26 ou mais novo pela App Store.
2. Abra `Canopy.xcodeproj` no Xcode.
3. Escolha o esquema **Canopy** e o destino **My Mac**, e aperte ⌘R.

O app não tem ícone no Dock. Ele aparece como uma cápsula na barra de menus e como uma ilha preta no notch. Passe o mouse no notch para abrir; clique para mantê-la aberta; clique fora para fechar. Em telas sem notch, a ilha aparece como uma pílula no topo da tela.

Para testar o estado compacto, ligue **Atividade de teste** no menu da barra.

## O que a ilha mostra

- **Música** do Apple Music e do Spotify: capa, faixa, progresso e controles. Na primeira vez, o macOS pede permissão de Automação para cada player; sem ela, a ilha mostra a faixa mas sem capa e sem controles.
- **Bateria**: aviso rápido ao ligar ou desligar o carregador e quando a bateria chega a 10%.
- **Microfone e câmera**: enquanto algum app usa um deles.
- **Volume**: um indicador rápido quando o volume muda.

A ilha aberta usa Liquid Glass; dá para voltar ao fundo preto em **Ajustes**.

## Estrutura

- `Canopy/`: o app (AppKit + SwiftUI): janela do notch, coordenador de atividades, interface e ajustes.
- `CanopyKit/`: pacote Swift com a lógica que não depende de AppKit (estados da ilha, fila de prioridade, geometria do notch) e os testes dela.

Testes do pacote: `swift test --package-path CanopyKit`.
