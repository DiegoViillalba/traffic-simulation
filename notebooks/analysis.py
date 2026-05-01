"""
Code utilities for the analysis of the traffic simulation results,
including loading configurations, plotting results, and computing metrics.
"""


import numpy as np
import matplotlib.pyplot as plt
import yaml
import os
import pandas as pd
from pathlib import Path

import scienceplots

plt.style.use('science')

import logging

logging.basicConfig(level=logging.WARNING, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def _assert_file_exists(file_path):
    """Helper function to check if a file exists."""
    if not os.path.isfile(file_path):
        raise FileNotFoundError(f"File not found: {file_path}")

def load_config(config_path):
    """Load a YAML configuration file."""
    _assert_file_exists(config_path)    
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
    return config

def load_results(results_path):
    """Load simulation results from a directory containing resumen.yaml and velocidades.csv."""
    logger.info(f"Loading results from: {results_path}")
    
    results_dir = Path(results_path)
    if not results_dir.exists():
        raise FileNotFoundError(f"Results directory not found: {results_dir}")
    
    # Load YAML summary
    yaml_path = results_dir / "resumen.yaml"
    _assert_file_exists(yaml_path)

    summary = yaml.safe_load(yaml_path.read_text())
    logger.info("Simulation Summary:")
    for key, value in summary.items():
        logger.info(f"{key}: {value}")
    
    # Load CSV data
    csv_path = results_dir / "velocidades.csv"
    _assert_file_exists(csv_path)

    data = pd.read_csv(csv_path)
    logger.info(f"Loaded {len(data)} rows from CSV")
    
    return data, summary

def get_density(cfg):
    """Calculate traffic density from the configuration."""
    n_total = cfg.get("vehiculos", {}).get("n", 0) + cfg.get("vehiculos", {}).get("m", 0)
    vehicle_area = cfg.get("vehiculos", {}).get("ancho", 0) * cfg.get("vehiculos", {}).get("largo", 0)
    highway_area= cfg.get("carretera", {}).get("L", 0) * 2
    density = n_total * vehicle_area / highway_area
    return density

def plot_acg_speed(sims, labels):
    """Plot average speed vs. density for multiple simulations."""
    plt.figure(figsize=(8, 5))
    for data, label in zip(sims, labels):
        density = get_density(data['summary'])
        avg_speed = data['velocidad'].mean()
        plt.scatter(density, avg_speed, label=label)
    
    plt.xlabel('Densidad (vehículos/m)')
    plt.ylabel('Velocidad Promedio (m/s)')
    plt.title('Curva ACG: Velocidad Promedio vs. Densidad')
    plt.legend()
    plt.grid(True)
    plt.show()