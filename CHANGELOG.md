# Changelog

## 1.1.0

- Relatório por dia (`/andarilho relatorio` ou botão direito no ícone do minimapa): filtros de 7 dias, 30 dias e tudo, este personagem ou todos, pesquisa por data ou dia da semana, total, média por dia e melhor dia.
- O histórico por dia começa a ser gravado nesta versão.
- Botão de minimizar na janela e ícone no minimapa para abrir de novo. O ícone pode ser arrastado e escondido com `/andarilho minimapa`.
- Opção de idioma: automático (segue o cliente do WoW), português ou inglês. Troca pelo botão no relatório ou com `/andarilho idioma auto|pt|en`.
- A janela mostra também a distância de hoje.

## 1.0.1

- Corrigido o erro "attempt to compare local 'speed' (a secret number value)". O WoW Forever esconde a velocidade do jogador, então o addon passou a usar só a posição e os eventos de movimento.
- Em dungeons a distância agora é estimada pela velocidade base enquanto você se move.

## 1.0.0

- Primeira versão.
- Contagem da distância a pé, montado e nadando, por personagem e somando todos.
- Conversão de yards para metros e km.
- Janela móvel com tooltip detalhado.
- Comandos `/andarilho`, `total`, `trancar`, `centro` e `reset`.
- Português (Brasil) e inglês.
