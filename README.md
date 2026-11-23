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

Start your docker deamon:

```bash
sudo systemctl start docker
#sudo systemctl enable docker
systemctl status docker
```

Run these from the root of the experimentation-platform repository (i.e. here, where this readme is):

```bash
docker compose -f samples/adaptable-teastore-image/docker-compose.yml up -d
# Check that the containers are running
docker compose -f samples/adaptable-teastore-image/docker-compose.yml ps
# Turn off the containers
docker compose -f samples/adaptable-teastore-image/docker-compose.yml down
```

The first up -d downloads the images, so it can take a few minutes. After that, the services need about a minute to register with each other.

Then, you can run the JavaBip controller (TODO: Update the rest of this readme)

