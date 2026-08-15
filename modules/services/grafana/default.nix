{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "d /srv/grafana 0755 472 472 - -"
    "d /srv/prometheus 0755 root root - -"
    "d /srv/loki 0755 root root - -"
  ];  

  virtualisation.oci-containers.containers = {
    
    grafana = {
      image = "grafana/grafana:latest@sha256:e27e68cfd5795c1bea54950766078a02e84dfa3bafe0a4d0e5382f713dfd8e4e";
      autoRemoveOnStop = false;
      volumes = [ 
        "/srv/grafana:/var/lib/grafana"
        "${./datasources.yaml}:/etc/grafana/provisioning/datasources/datasources.yml:ro"
      ];
      extraOptions = [ "--network=host" ];
    };

    loki = {
      image = "grafana/loki:latest@sha256:83c76da7858a8f4f88117ac521864ac33896fdae7a352a1df4068556e7513f64";
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
      image = "prom/prometheus:latest@sha256:1147c92841726a6fef55fe6124491d6f85480f8de204f7d420304ca5bbd0a8f7";
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
