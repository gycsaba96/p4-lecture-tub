
# Ping offloading example

The repository contains an example P4 program for educational purposes. Two hosts are connected via a P4-programmable switch. Thanks to the P4 program, the switch answers ping requests on behalf of the hosts.

## Running the P4 program

1. Make sure that you have [p4app](https://github.com/p4lang/p4app) installed.

2. You can start the P4 program using the following command:

    ```
    sudo p4app run ping.p4app
    ```

    The first start might take longer since `p4app` will pull some docker images.

    You should get a `mininet` console at the end.

3. The `experiment.sh` script configures the network, and then one host pings the other. You can run it using the following command:

    ```
    sudo bash experiment.sh
    ```

    Make sure that you are running it in a different terminal, not in the `mininet` console.
