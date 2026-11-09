<p align="center">
  <img src="docs/logo.png" alt="Andarilho" width="160">
</p>

<h1 align="center">Andarilho</h1>

<p align="center">
  <b>Quantos quilômetros você já caminhou em Azeroth?</b><br>
  Addon para <b>WoW Forever</b> que conta a distância percorrida e converte de yards para metros e km.
</p>

<p align="center">
  <img alt="WoW Forever" src="https://img.shields.io/badge/WoW-Forever-33cc66">
  <img alt="Versão 1.0.0" src="https://img.shields.io/badge/vers%C3%A3o-1.0.0-blue">
  <img alt="Licença MIT" src="https://img.shields.io/badge/licen%C3%A7a-MIT-lightgrey">
</p>

---

## O que ele faz

- **Conta o que você realmente andou**, em yards, metros e km.
- **Separa por tipo:** a pé, montado e nadando.
- **Guarda por personagem** e também soma todos os personagens da conta.
- **Mostra a sessão atual** ao lado do total.
- **Janela pequena e móvel**, com o detalhe completo no tooltip.
- **Não conta o que não é andar:** Taxi, teleporte, barco, zepelim e correr parado contra a parede.

## Instalação

1. Baixe o zip na página de [Releases](../../releases) ou no CurseForge.
2. Extraia a pasta `Andarilho` em `World of Warcraft\_forever_\Interface\AddOns\`.
3. Entre no jogo. A janela aparece sozinha, e a contagem começa ali.

## Comandos

| Comando | O que faz |
|---|---|
| `/andarilho` | Mostra ou esconde a janela |
| `/andarilho total` | Escreve os totais no chat |
| `/andarilho trancar` | Trava ou destrava a posição da janela |
| `/andarilho centro` | Traz a janela de volta ao centro |
| `/andarilho reset confirmar` | Zera a contagem deste personagem |

## Como a distância é medida

A cada 0,2 segundo o addon compara a posição atual do personagem com a anterior, usando a velocidade informada pelo jogo como limite. É isso que descarta teleportes e o tempo correndo contra uma parede.

- **Dungeons:** o jogo não informa a posição, então o cálculo passa a ser velocidade × tempo.
- **Altura:** a distância é horizontal, então subir ou cair não soma.
- **Início da contagem:** o jogo não guarda o histórico, então só conta a partir da instalação.
- **Conversão:** 1 yard = 0,9144 m.

## Desenvolvimento

O teste roda fora do jogo, com a API do WoW simulada:

```
lua5.1 tools/test/test.lua Andarilho/Andarilho.lua
```

Para publicar uma versão nova, altere o `## Version` em `Andarilho/Andarilho.toc` e envie para o `main`. O GitHub Actions cria a tag e o Release e envia para o CurseForge.

## English

Andarilho is a **WoW Forever** addon that tracks how far your character has travelled and converts yards to meters and kilometers. It keeps separate totals for on foot, mounted and swimming, per character and across the account, and ignores flight paths, teleports, boats and running into walls. Use `/andarilho` to show or hide the window; the commands `total`, `lock`, `center` and `reset confirm` are also available.

## Créditos

Criado por **Ianes**. Escrito com a ajuda do Claude (Anthropic). Licença [MIT](LICENSE).
