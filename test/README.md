# Testes Unitários

Testes para validar a estrutura do arquivo `sync_selection.txt` e como o script `dap_sync.sh` processa esse arquivo.

## Estrutura dos Testes

### `sync_selection_test.rb`
Testa as funções de leitura e escrita do arquivo de seleção no backend Ruby:
- Leitura de formato JSON (novo formato)
- Leitura de formato legado ("*" ou lista de álbuns)
- Escrita de seleções em formato JSON
- Tratamento de arquivos vazios ou ausentes
- Validação de estrutura JSON

### `ipod_sync_parser_test.rb`
Testa como o script bash `dap_sync.sh` deve processar o arquivo:
- Parsing de formato JSON usando Python
- Parsing de formato legado
- Validação de estrutura esperada pelo script
- Casos de borda (arquivo vazio, JSON inválido, etc.)

### `sync_selection_format_test.rb`
Testa o formato correto do arquivo `sync_selection.txt`:
- Verifica que paths são escritos com `MUSIC_DIRECTORY` e `AUDIOBOOKS_DIRECTORY` (paths do host)
- Garante que paths do container (`/music/`, `/audiobooks/`) são convertidos para paths do host
- Valida que paths relativos são convertidos corretamente
- Testa que paths que já são do host não são modificados
- Verifica formato correto (sem espaços extras, uma linha por item, sem linhas MODE)
- Testa casos especiais (caracteres especiais, estruturas planas, paths vazios)

## Executar Testes

```bash
# Instalar dependências de teste
bundle install

# Executar todos os testes
bundle exec rake test

# Ou executar um arquivo específico
ruby test/sync_selection_test.rb
ruby test/ipod_sync_parser_test.rb
ruby test/sync_selection_format_test.rb
ruby test/new_format_test.rb
ruby test/full_path_selection_test.rb
```

## Estrutura Esperada do sync_selection.txt

### Formato Novo (key=value, sem dependência de Python)
O arquivo agora usa um formato simples de texto que pode ser parseado diretamente em bash, **sem necessidade de Python ou JSON**:

```
MUSIC_ALBUM=/Users/sergio/Music/Music/Media.localized/Music/Artist1/Album1
MUSIC_ALBUM=/Users/sergio/Music/Music/Media.localized/Music/Artist2/Album2
AUDIOBOOKS=/Users/sergio/Library/OpenAudible/books/Audiobook1.m4b
AUDIOBOOKS=/Users/sergio/Library/OpenAudible/books/Audiobook2.m4b
```

**Formato:**
- `MUSIC_ALBUM=/path/completo` - um álbum por linha. Se não houver linhas `MUSIC_ALBUM=`, todos os álbuns serão sincronizados.
- `AUDIOBOOKS=/path/completo` - um audiobook por linha. Se não houver linhas `AUDIOBOOKS=`, todos os audiobooks serão sincronizados.
- Linhas vazias e linhas começando com `#` são ignoradas
- Quando "Sync All" é selecionado na UI, **todos os álbuns/audiobooks são listados explicitamente** no arquivo

**Nota:** A UI ainda trabalha com paths relativos, mas o arquivo salva paths completos. O backend converte automaticamente ao ler/escrever.

### Formato Legado (Compatibilidade)
O sistema ainda suporta os formatos antigos para compatibilidade:
- Formato JSON (antigo)
- Formato texto simples com `*` ou lista de álbuns (muito antigo)

### Formato Legado
- `*` ou arquivo vazio → sincroniza tudo
- Lista de álbuns (um por linha) → sincroniza apenas os listados

## Validações

Os testes validam:
1. ✅ Estrutura JSON completa (music e audiobooks)
2. ✅ Valores de mode válidos ("all" ou "selected")
3. ✅ Arrays de álbuns/audiobooks quando mode é "selected"
4. ✅ Compatibilidade com formato legado
5. ✅ Tratamento de erros (arquivo ausente, JSON inválido)
6. ✅ Remoção de whitespace e linhas vazias
7. ✅ **Paths são escritos com `MUSIC_DIRECTORY` e `AUDIOBOOKS_DIRECTORY` (host paths)**
8. ✅ **Paths do container (`/music/`, `/audiobooks/`) são convertidos para host paths**
9. ✅ **Formato correto: sem linhas MODE, uma linha por item, sem espaços extras**
10. ✅ **Casos especiais: caracteres especiais, estruturas planas, paths vazios**
