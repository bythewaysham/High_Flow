# 🐝 HiveFlow: The Self-Healing Brain for Warehouse Robot Fleets

**KRS Robotics & AI Hackathon | 27 October 2026**
**Challenge Track:** Track 3: Smart Logistics & Warehouse Automation
**Team Name:** Team Code Breakers | **Category:** Software | **Team Size:** 5 members
**Institution:** IILM Greater Noida

---

## 📖 Overview

> *"Robots are fast. Their coordination is not."*

**HiveFlow** is a robot-agnostic, software-only "brain" that sits on top of any existing robot fleet to assign, route, and heal operations in real-time. By introducing rolling-horizon replanning and a reservation table, HiveFlow eliminates the catastrophic deadlocks, wasted trips, and black-box decisions caused by traditional "nearest robot, shortest path" dispatch logic. 

No hardware changes are required—HiveFlow simply makes your existing fleet smarter.

---

## 🛑 The Problem

Traditional warehouse fleets suffer from severe coordination issues:
*   **The Dispatch Flaw:** Standard "nearest robot, shortest path" logic causes narrow aisles to become heavily congested.
*   **The Domino Effect:** A single breakdown or blocked aisle can stall an entire warehouse zone.
*   **The Black Box:** Operators have zero visibility into *why* the system made a specific routing or assignment decision.
*   **The Bottlenecks:** Fleets fail to efficiently batch orders that share aisles or account for real-time variables like battery life and congestion.

### 🚨 Real-World Impact (The Ocado Incident, 2021)
Without proper coordination, the consequences are disastrous. In 2021, just **3 robots collided** at an Ocado fulfillment centre, triggering a fire. 
*   **300,000** orders lost
*   **£35 million** estimated revenue impact
*   **0** injuries reported (but massive operational disruption)

---

## 🧠 The HiveFlow Solution

HiveFlow acts as a centralized, intelligent brain that takes in **Customer Orders** and **Live Robot Status** (position, battery, faults), processes them through four core modules, and outputs commands to the fleet with a **one-line reason for every decision**.

### Core Modules (How it Works):
1.  **Order Batching:** Groups orders that share aisles to minimize travel.
2.  **Task Assignment:** Assigns tasks using a lowest total cost algorithm: *Travel + Battery + Congestion*.
3.  **Space-Time A\* Routing:** Plans conflict-free routes in both space and time.
4.  **Reservation Table:** Books grid cells in advance to avoid collisions and forecast congestion.
5.  **Local Healing (Resilience):** If an aisle is blocked, a robot fails, or a rush order arrives, *only the affected robots* replan. There is no need for whole-fleet replanning.

### ✅ With HiveFlow:
*   **Prevents** route conflicts & collisions.
*   **Adapts** to failures and blockages.
*   **Optimises** task assignment and batching.
*   **Reduces** idle time and unnecessary travel.

---

## 🛠️ Technologies Used

*   **Languages/Libraries:** Python, NumPy, SciPy
*   **Frontend/Visualization:** HTML/JS Live Map
*   **Environment:** Seeded simulation (ensures reproducible, side-by-side testing against the baseline)

---

## 📊 Proof & Decision Trace

We don't just claim it works; we prove it. Every decision made by HiveFlow features a one-line reason for total transparency.

👉 **Live Demo:** [hiveflow.pages.dev](https://hiveflow.pages.dev/)

**Interactive Controls to Test Self-Healing:**
*   🚧 Block Aisle
*   💀 Kill Robot
*   ⚡ Trigger Rush Order

### Baseline vs. HiveFlow Target Metrics
*(Targets to be confirmed by our seeded simulation)*

| Metric | Baseline (Nearest Robot + Shortest Path) | HiveFlow (Target) |
| :--- | :--- | :--- |
| **Orders per hour** | Lower | **Higher** |
| **Average cycle time** | Longer | **Shorter** |
| **Deadlocks** | Occur in busy aisles | **Zero by design** |
| **Distance / Idle %** | Higher | **Lower** |

---

## 💡 Feasibility and Viability

*   **Software Only:** Requires no new robots, sensors, or hardware.
*   **Robot-Agnostic:** Works with any brand through an **Adapter Layer**.
*   **Commercial Model:** Subscription per robot or per warehouse. Target markets include E-commerce, 3PL, Pharma, and Cold Storage.
*   **Next Step:** Simulation prototype is built; **real-robot API test is the immediate next step.**

### Challenges & How We Overcome Them

| Challenge / Risk | Our Solution |
| :--- | :--- |
| **Tested in simulation, not yet on real robots** | Pilot in one warehouse zone first, then scale. |
| **Each robot vendor has a different API** | Adapter layer converts HiveFlow commands to each vendor API. |
| **Real floors have delays and sensor noise** | Rolling-horizon replanning corrects from each robot's real-time position. |
| **Larger fleets need faster planning** | Local replanning keeps compute small as the fleet grows. |

---

## 🔬 Research & References

**What We Studied:**
*   Multi-Agent Path Finding (MAPF)
*   Space-Time A\* and Reservation Tables
*   Assignment Algorithms (Hungarian Method)
*   Warehouse Automation and Order Picking

**Learning Resources:**
1.  [Uday.ai (YouTube)](https://youtu.be/AleDm8Fxclq)
2.  Google AI Mode: Background research on warehouse robot coordination (2026)

**AI Tools Used (Disclosed as required):**
*   **Claude (Anthropic):** Explanations, planning, and drafting
*   **DeepSeek:** Model Designing
*   **Gamma AI:** Initial slide design

---

## 👥 Team Code Breakers

*   **Institution:** IILM Greater Noida
*   **Team Size:** 5 Members

📱 **Scan to View Prototype:**
*(Insert QR Code from Slide 6 here)*
