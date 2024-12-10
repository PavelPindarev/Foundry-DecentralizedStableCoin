# Foundry DeFi Stablecoin Project

A decentralized application enabling users to deposit assets like WETH and WBTC to mint a USD-pegged stablecoin.

## Table of Contents
- [Foundry DeFi Stablecoin Project](#foundry-defi-stablecoin-project)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Setup](#setup)
    - [Requirements](#requirements)
    - [Quick Start](#quick-start)

---

## Introduction

This repository demonstrates a decentralized stablecoin system using the Foundry toolchain. The stablecoin allows collateralization with WETH and WBTC, aiming to maintain a 1:1 peg with the US Dollar.

## Setup

### Requirements

- [Git](https://git-scm.com/): `git --version`
- [Foundry](https://getfoundry.sh/): `forge --version`

### Quick Start

Clone the repository and build the project:

```bash
git clone <repository-url>
cd <repository-directory>
forge build
