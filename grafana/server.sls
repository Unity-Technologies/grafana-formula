{%- from "grafana/map.jinja" import server with context %}
{%- if server.get('enabled', False) %}

grafana_repo:
  pkgrepo.managed:
    - name: deb https://packagecloud.io/grafana/stable/debian/ jessie main
    - file: /etc/apt/sources.list.d/grafana.list
    - key_url: https://packagecloud.io/gpg.key
    - require_in:
      - pkg: grafana_packages

grafana_packages:
  pkg.installed:
  - names: {{ server.pkgs }}
  cmd.run:
    - name: setcap 'cap_net_bind_service=+ep' /usr/sbin/grafana-server
    - unless: getcap /usr/sbin/grafana-server | grep 'cap_net_bind_service+ep'
    
/etc/grafana/grafana.ini:
  file.managed:
  - source: salt://grafana/files/grafana.ini
  - template: jinja
  - user: grafana
  - group: grafana
  - require:
    - pkg: grafana_packages

{%- if server.dashboards.enabled %}

grafana_copy_default_dashboards:
  file.recurse:
  - name: {{ server.dashboards.path }}
  - source: salt://grafana/files/dashboards
  - user: grafana
  - group: grafana
  - require:
    - pkg: grafana_packages
  - require_in:
    - service: grafana_service

{%- endif %}

{%- for theme_name, theme in server.get('theme', {}).iteritems() %}

{%- if theme.css_override is defined %}

grafana_{{ theme_name }}_css_override:
  file.managed:
  - names:
    - {{ server.dir.static }}/css/grafana.{{ theme_name }}.min.css
    {%- if theme.css_override.build is defined %}
    - {{ server.dir.static }}/css/grafana.{{ theme_name }}.min.{{ theme.css_override.build }}.css
    {%- endif %}
  - source: {{ theme.css_override.source }}
  {%- if theme.css_override.source_hash is defined %}
  - source_hash: {{ theme.css_override.source_hash }}
  {%- endif %}
  - user: grafana
  - group: grafana
  - require:
    - pkg: grafana_packages
  - require_in:
    - service: grafana_service

{%- endif %}

{%- endfor %}

grafana_service:
  service.running:
  - name: {{ server.service }}
  - enable: true
  # It is needed if client is trying to set datasource or dashboards before
  # server is ready.
  - init_delay: 5
  - watch:
    - file: /etc/grafana/grafana.ini

{%- endif %}
