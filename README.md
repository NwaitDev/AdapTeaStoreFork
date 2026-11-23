# JavaBIP-TeaStore

This project contains two JavaBIP implementations of an adaptive cache control system for a TeaStore.

## Context

This repository contains two complementary projects :

- **[javabipteastore](src/main/java/javabipteastore/)** — A JavaBIP translation of the [CollectiveTeaStoreVariation](https://github.com/NwaitDev/CollectiveTeaStoreVariation), adapted for 3 clients instead of 10. 
It reproduces the behavior of a multi-client system with a PID controller that dynamically adjusts an LRU cache size.

- **[adapteastore](src/main/java/adapteastore/)** — A BIP controller that interfaces with the [Adaptable TeaStore](https://gitlab.inria.fr/adaptable-teastore/experimentation-platform) using the [AdaptiFlow](https://github.com/brice10/adaptiflow-core/tree/main) framework. It monitors persistence layer metrics, computes an adjustment via the same PID controller, and updates the image cache size through REST service.
Note that the PID controller is not adapted to the Adaptable TeaStore's behavior, it is a direct reuse of the javabipteastore controller.



## To setup the experiments

```bash
chmod +x install-javabip-jars.sh
./install-javabip-jars.sh
mvn package -DskipTests

# Only needed for Adapteastore (builds Siphonix and fetches its AdaptiFlow plugin and scenarios)
./fetch-siphonix.sh
```

## To run the experiments

### javabipteastore

```bash
java -cp target/JavaBIP-TeaStore-1.0-SNAPSHOT-jar-with-dependencies.jar javabipteastore.Main
```

- It stops by itself once every client has loaded 600 images, or once the cache reaches its maximum size.
- It writes src/main/java/TeaStoreWithConnector/output/cache_history_KP0.8_KI0.05_KD0.2.csv.
- To try other PID values, change KP, KI and KD in Main.java and rebuild. There is also a grid search over many values in main(). It is commented out and takes a long time. Its loop calls runDemo(p, i, d), but runDemo currently takes no arguments, so you’d need to restore those parameters before it compiles.

To plot the results :
```bash
pip install pandas numpy matplotlib plotly

# One run (matplotlib)
python3 src/main/java/javabipteastore/plot.py \
  src/main/java/TeaStoreWithConnector/output/cache_history_KP0.8_KI0.05_KD0.2.csv

# Several runs compared (interactive Plotly, label each with "file:label")
python3 src/main/java/javabipteastore/plotMultiple.py \
  "run_a.csv:Kp=0.8" "run_b.csv:Kp=1.0" --output=compare.html
```


### Adapteastore

Requirements: a JDK (11+), Maven, Git, curl and a running Docker daemon (`sudo systemctl start docker`).

```bash
./run-adapteastore.sh                    # set up what is missing, start everything, run the controller
./run-adapteastore.sh --rebuild          # same, after rebuilding the controller and Siphonix from scratch
./run-adapteastore.sh --keep-containers  # leave the TeaStore running when the controller stops
```

The script:
1. Installs the JavaBIP jars in `~/.m2`, builds the controller and fetches Siphonix (`fetch-siphonix.sh`) if they are missing.
2. Builds the `image` service with Siphonix and starts the Adaptable TeaStore and the load generator (`samples/adaptable-teastore-image/run.debug.sh`).
3. Waits until the image service answers on `http://localhost:8083` (the first run downloads the images and can take a few minutes).
4. Runs `adapteastore.Main`, which polls the image service request count every 2 s and posts the cache size computed by the PID controller.

Stop it with Ctrl+C; the containers are then shut down. The web UI is at http://localhost:8080.

To manage the containers by hand:

```bash
docker compose -f samples/adaptable-teastore-image/docker-compose.yml -p adaptable-teastore-image ps
docker compose -f samples/adaptable-teastore-image/docker-compose.yml -p adaptable-teastore-image logs image
docker compose -f samples/adaptable-teastore-image/docker-compose.yml -p adaptable-teastore-image down
```

