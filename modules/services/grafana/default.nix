{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "d /srv/grafana 0755 472 472 - -"
    "d /srv/prometheus 0755 root root - -"
    "d /srv/loki 0755 root root - -"
  ];  

  virtualisation.oci-containers.containers = {
    
    grafana = {
      image = "grafana/grafana:latest";
      autoRemoveOnStop = false;
      volumes = [ 
        "/srv/grafana:/var/lib/grafana"
        "${./datasources.yaml}:/etc/grafana/provisioning/datasources/datasources.yml:ro"
      ];
      extraOptions = [ "--network=host" ];
    };

    loki = {
      image = "grafana/loki:latest";
      user = "root";
      autoRemoveOnStop = false;
      volumes = [
        "/srv/loki:/loki"
        "${./loki.yaml}:/etc/loki/local-config.yaml:ro"      
      ];
      cmd = [ "-config.file=/etc/loki/local-config.yaml" ];
      extraOptions = [ "--network=host" ];
    };

    prometheus = {
      image = "prom/prometheus:latest";
      user = "root";
      autoRemoveOnStop = false;
      volumes = [ 
        "/srv/prometheus:/prometheus"
        "${./prometheus.yml}:/etc/prometheus/prometheus.yml:ro"
      ];
      cmd = [ 
        "--config.file=/etc/prometheus/prometheus.yml" 
        "--web.enable-remote-write-receiver" 
      ];
      extraOptions = [ "--network=host" ];
    };
    
  };
}
