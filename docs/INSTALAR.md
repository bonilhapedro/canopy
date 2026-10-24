# Instalar o Canopy como um app normal

Assim o Canopy fica em Aplicativos, abre sem o Xcode e pode abrir sozinho quando você entra no Mac.

## Uma vez só: criar um certificado com o seu Apple ID (grátis)

Sem certificado, o macOS trata cada build como um app novo e esquece as permissões (Acessibilidade, Bluetooth, Automação). Com um certificado "Apple Development", que qualquer Apple ID ganha de graça, as permissões ficam.

1. Abra o Xcode e vá em **Xcode › Settings… › Accounts**.
2. Clique no **+** embaixo, escolha **Apple ID** e entre com a sua conta.
3. Selecione a conta, clique em **Manage Certificates…**, depois no **+** e em **Apple Development**. Feche a janela.

Para conferir, rode no Terminal:

```sh
security find-identity -v -p codesigning
```

Deve aparecer uma linha com `Apple Development: seu nome (...)`.

## Gerar e instalar

No Terminal, dentro da pasta do projeto:

```sh
cd ~/caminho/para/canopy
git checkout main && git pull
scripts/package.sh --install
```

O script faz o build de Release, assina com o seu certificado, copia o app para **/Applications** e abre. Na primeira vez o macOS pode pedir a senha do Chaveiro para usar o certificado: digite a senha do Mac e clique em **Sempre Permitir**.

Ele também deixa um `Canopy-<versão>.dmg` em `build/package/`, que serve para guardar ou levar para outro Mac seu.

Para atualizar depois, é só repetir `git pull` e `scripts/package.sh --install`. As permissões continuam valendo.

## Abrir sozinho ao entrar no Mac

No Canopy instalado, abra **Ajustes** pela cápsula na barra de menus e ligue **Abrir o Canopy ao iniciar sessão**.

Se você já tinha ligado essa opção rodando pelo Xcode, desligue e ligue de novo no app de /Applications, para o macOS abrir o app certo. Em **Ajustes do Sistema › Geral › Itens de Início** o Canopy deve aparecer uma vez só.

## Permissões depois de instalar

O app instalado é visto pelo macOS como o mesmo app de antes só se a assinatura for a mesma. Na primeira vez com o certificado novo, refaça as permissões:

- **Acessibilidade** (esconder o indicador de volume e brilho do macOS): em **Ajustes do Sistema › Privacidade e Segurança › Acessibilidade**, tire as entradas antigas do Canopy com o botão **−** e ligue a nova.
- **Automação**, **Agenda**, **Localização** e **Bluetooth**: o macOS pergunta de novo na primeira vez que o Canopy usar cada uma.

Depois disso não precisa repetir a cada atualização.

## Quando usar o Xcode

Para desenvolver, continue usando o Xcode (⌘R). Antes, feche o Canopy instalado (cápsula na barra de menus › Sair), para não ter duas ilhas abertas. Para o Xcode também usar o seu certificado, escolha o seu nome em **Team** na aba **Signing & Capabilities** do alvo Canopy.

## O .dmg do GitHub

A cada push no `main`, o GitHub gera um .dmg em **Actions › Pacote** (no fim da página do job, em Artifacts). Numa tag `v0.1.0`, ele também vira uma Release.

Esse .dmg sai com assinatura ad hoc, porque o GitHub não tem o seu certificado. Ele funciona, mas:

- Na primeira vez, o macOS bloqueia o app. Tente abrir, depois vá em **Ajustes do Sistema › Privacidade e Segurança** e clique em **Abrir Mesmo Assim**.
- As permissões caem a cada versão nova, como no build sem certificado.

Para o seu próprio Mac, o `scripts/package.sh --install` é o melhor caminho.

## Distribuir para outras pessoas

Para outra pessoa abrir o Canopy sem avisos, o app precisa de um certificado **Developer ID** e de notarização da Apple. Isso exige o Apple Developer Program (US$ 99 por ano). O Canopy não pode ir para a App Store, porque usa recursos que ela não permite (interceptar as teclas de volume e brilho e a API privada de brilho).

Com a conta paga:

1. Em **Xcode › Settings › Accounts › Manage Certificates**, crie um **Developer ID Application**.
2. Salve a senha de app para a notarização (crie uma em account.apple.com › Senhas de app):

   ```sh
   xcrun notarytool store-credentials canopy --apple-id seu@email.com --team-id SEUTEAMID
   ```

3. Gere o .dmg notarizado:

   ```sh
   NOTARY_PROFILE=canopy scripts/package.sh
   ```

O script escolhe o Developer ID sozinho quando ele existe no Chaveiro.
