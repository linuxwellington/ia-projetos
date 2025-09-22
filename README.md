# Dashboard de Auditoria OpenVPN (Docker + PostgreSQL)

Projeto para provisionar, via script, um dashboard estático de auditoria de acessos OpenVPN junto a uma stack Docker (Nginx + PostgreSQL + pgAdmin).

- Frontend estático com Bootstrap e Font Awesome
- Banco de dados PostgreSQL com schema inicial e dados de exemplo
- Orquestração via Docker Compose

## Sumário
- [Visão geral](#visão-geral)
- [Requisitos](#requisitos)
- [Estrutura provisionada](#estrutura-provisionada)
- [Serviços e portas](#serviços-e-portas)
- [Banco de dados](#banco-de-dados)
- [Como executar](#como-executar)
- [Configurações](#configurações)
- [Backup e restauração](#backup-e-restauração)
- [Systemd (opcional)](#systemd-opcional)
- [Segurança](#segurança)
- [Solução de problemas](#solução-de-problemas)
- [Licença](#licença)

## Visão geral
- Script principal: `dashboard-auditoria.sh` (internamente citado como `install_openvpn_audit_postgres_menus.sh`).
- Automatiza: instalação de dependências, criação de estrutura em `/opt/openvpn-audit`, arquivos HTML/CSS, Nginx, `docker-compose.yml` e `postgres/init.sql`, além de iniciar os serviços.

## Requisitos
- Acesso root (executar com `sudo`)
- Linux suportado: Ubuntu/Debian, CentOS/RHEL/Rocky/Alma, Fedora
- Acesso à internet para baixar pacotes, imagens Docker e Font Awesome

O script instala automaticamente, se necessário:
- Docker
- Docker Compose
- Pacotes de sistema (curl, wget, unzip, git, etc.)

## Estrutura provisionada
```
/opt/openvpn-audit/
  ├─ html/              # páginas estáticas (index.html, css, webfonts, pages)
  ├─ nginx/
  │   ├─ nginx.conf
  │   └─ default.conf
  ├─ postgres/
  │   └─ init.sql       # criação de tabelas, índices e dados exemplo
  ├─ backup/            # backups gerados por backup.sh
  ├─ docker-compose.yml
  ├─ start.sh           # inicia os serviços
  └─ stop.sh            # para os serviços
```

## Serviços e portas
| Serviço   | Porta(s) | Container                     | Observações                               |
|-----------|----------|-------------------------------|--------------------------------------------|
| Nginx     | 80, 443  | `openvpn_audit_nginx`         | Serve conteúdo estático de `html/`         |
| PostgreSQL| 5432     | `openvpn_audit_postgres`      | DB `openvpn_audit`                         |
| pgAdmin   | 5050     | `openvpn_audit_pgadmin`       | Interface web para o PostgreSQL            |

Rede Docker: `openvpn_audit_network` (bridge) • Volume: `postgres_data` (persistência do DB)

## Banco de dados
- DB: `openvpn_audit`
- Usuário: `audituser`
- Senha: `auditpass123`
- Extensão habilitada: `pg_stat_statements`

Em `postgres/init.sql`:
- Tabela `usuarios` (`login`, `data_inicio`, `data_fim`, `status_documentacao` = OK|Faltando, links e timestamps)
- Tabela `auditoria` (ações por usuário)
- Trigger para atualizar `updated_at` em `usuarios`
- Índices em colunas-chave e inserção de dados de exemplo

## Como executar
1) Tornar o script executável e rodar como root:
```bash
chmod +x dashboard-auditoria.sh
sudo ./dashboard-auditoria.sh
```
2) Confirmar a instalação quando solicitado (`s`).
3) Acessos após concluir:
   - Dashboard: `http://localhost`
   - pgAdmin: `http://localhost:5050`
   - PostgreSQL: `localhost:5432`

Gerenciar serviços posteriormente:
```bash
sudo /opt/openvpn-audit/start.sh
sudo /opt/openvpn-audit/stop.sh
```

Logs:
```bash
cd /opt/openvpn-audit && docker-compose logs -f
```

## Configurações
- Edite credenciais em `docker-compose.yml` para produção:
  - `POSTGRES_USER`, `POSTGRES_PASSWORD`, `PGADMIN_DEFAULT_EMAIL`, `PGADMIN_DEFAULT_PASSWORD`
- Ajuste `nginx/default.conf` e `nginx/nginx.conf` conforme domínio/política de segurança
- Frontend é estático (não consome o DB diretamente). Para dados dinâmicos, crie uma API e integre.

## Backup e restauração
- Criar backup:
```bash
sudo /opt/openvpn-audit/backup.sh
```
Cria dump SQL do banco e tar.gz de HTML/configs em `/opt/openvpn-audit/backup`.

- Restaurar (resumo):
```bash
# Suba o Postgres com docker-compose e então
docker exec -i openvpn_audit_postgres psql -U audituser -d openvpn_audit < /caminho/para/backup_database.sql
```

## Systemd (opcional)
Unidade criada: `openvpn-audit.service`.
```bash
sudo systemctl daemon-reload
sudo systemctl enable openvpn-audit
sudo systemctl start openvpn-audit
sudo systemctl status openvpn-audit | cat
```

## Segurança
- Altere todas as senhas padrão antes de expor
- Restrinja portas via firewall/SG conforme necessário
- Avalie TLS no Nginx e uso de Docker secrets/variáveis de ambiente

## Solução de problemas
- Docker não inicia: verifique `systemctl status docker` e se seu usuário está no grupo `docker`
- Portas em uso: ajuste mapeamentos (`80`, `443`, `5050`, `5432`) em `docker-compose.yml`
- pgAdmin não conecta: host `postgres`, porta `5432`, usuário `audituser`, senha
- Font Awesome ausente: reexecute o script para repopular `html/css` e `html/webfonts`

## Licença
Não especificada. Defina uma licença se necessário.
