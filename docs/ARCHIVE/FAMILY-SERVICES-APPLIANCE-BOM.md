# Family Services Appliance - Bill of Materials (BOM)

## Pro Tier - Dual Orange Pi 5 Plus Configuration

**Target Cost:** $730-890  
**Timeline:** 2-3 weeks for sourcing and assembly

## Quick Purchase Links

### Recommended Suppliers

**United States:**
- Amazon: Fast shipping, easy returns (Prime)
- Newegg: Good for storage and networking
- AliExpress: Best prices for Orange Pi hardware (15-30 day shipping)
- B&H Photo: Quality components, good customer service

**International:**
- AliExpress Global: Ships worldwide
- Amazon International: Available in most countries
- Local distributors: Check Orange Pi official website

## Complete BOM - Pro Tier

### Computing Nodes (Quantity: 2)

| Item | Specification | Qty | Unit Price | Total | Supplier Links |
|------|---------------|-----|------------|-------|----------------|
| **Orange Pi 5 Plus** | 16GB RAM, RK3588 | 2 | $165 | $330 | [AliExpress](https://aliexpress.com) / [Amazon](https://amazon.com) |
| **NVMe SSD** | 512GB M.2 2280 | 2 | $50 | $100 | Samsung 970 EVO Plus [Amazon](https://amazon.com) |
| **eMMC Module** | 32GB for boot | 2 | $20 | $40 | Orange Pi official [AliExpress](https://aliexpress.com) |
| **Power Supply** | 12V/3A DC | 2 | $13 | $26 | Official adapter [AliExpress](https://aliexpress.com) |
| **Case** | Metal with cooling | 2 | $30 | $60 | Aluminum case [AliExpress](https://aliexpress.com) |
| **Subtotal** | | | | **$556** | |

### Network Infrastructure

| Item | Specification | Qty | Unit Price | Total | Supplier Links |
|------|---------------|-----|------------|-------|----------------|
| **Managed Switch** | 8-port GbE/2.5GbE | 1 | $45 | $45 | TP-Link TL-SG108E [Amazon](https://amazon.com) |
| **Ethernet Cables** | Cat6, 3ft (5-pack) | 1 | $15 | $15 | Monoprice [Amazon](https://amazon.com) |
| **Subtotal** | | | | **$60** | |

### Power & Protection

| Item | Specification | Qty | Unit Price | Total | Supplier Links |
|------|---------------|-----|------------|-------|----------------|
| **UPS** | 800VA/450W | 1 | $95 | $95 | CyberPower CP800AVR [Amazon](https://amazon.com) |
| **Power Strip** | 6-outlet surge | 1 | $15 | $15 | Belkin [Amazon](https://amazon.com) |
| **Subtotal** | | | | **$110** | |

### Accessories & Tools

| Item | Specification | Qty | Unit Price | Total | Supplier Links |
|------|---------------|-----|------------|-------|----------------|
| **USB-TTL Serial** | 3.3V debug adapter | 1 | $8 | $8 | CP2102 [Amazon](https://amazon.com) |
| **Anti-static Wrist Strap** | Grounding strap | 1 | $7 | $7 | Rosewill [Amazon](https://amazon.com) |
| **Thermal Paste** | Arctic MX-4 4g | 1 | $8 | $8 | [Amazon](https://amazon.com) |
| **Cable Ties** | Velcro straps | 1 | $10 | $10 | [Amazon](https://amazon.com) |
| **Subtotal** | | | | **$33** | |

### **TOTAL COST** | | | | **$759** | |

---

## Detailed Component Specifications

### 1. Orange Pi 5 Plus (16GB)

**Why this model:**
- Most powerful RK3588 SBC with 16GB RAM
- Native M.2 NVMe support (PCIe 3.0)
- Dual Ethernet (2.5GbE + 1GbE)
- Active community support
- Good thermal design

**Specifications:**
- SoC: Rockchip RK3588
  - CPU: Quad-core Cortex-A76 @ 2.4GHz + Quad-core Cortex-A55 @ 1.8GHz
  - GPU: Mali-G610 MP4
  - NPU: 6 TOPS AI acceleration
- RAM: 16GB LPDDR4X
- Storage interfaces:
  - M.2 M-Key 2280 (PCIe 3.0 x4)
  - eMMC socket
  - microSD card slot
- Network: 2.5GbE + 1GbE RJ45
- USB: 2× USB 3.0, 2× USB 2.0
- Video: HDMI 2.1, DP 1.4
- Power: 12V/3A DC barrel jack

**Where to buy:**
- **AliExpress** (Best price): $150-165
  - Seller: Orange Pi Official Store
  - Shipping: 15-30 days (free)
  - Warranty: 12 months
  
- **Amazon US** (Fast shipping): $180-200
  - Prime shipping available
  - Easy returns
  - Limited stock

**Alternative models:**
- Orange Pi 5 (8GB): $95 - Good for Basic tier
- Orange Pi 5B (16GB): $140 - Similar performance, different form factor
- Rock 5B (16GB): $150 - Alternative with similar specs

### 2. NVMe SSD - 512GB

**Recommended: Samsung 970 EVO Plus**

**Why:**
- Proven reliability (5-year warranty)
- Good performance: 3,500 MB/s read, 3,300 MB/s write
- Power efficient
- Wide temperature range

**Specifications:**
- Capacity: 500GB / 512GB
- Interface: M.2 2280 PCIe 3.0 x4 NVMe
- DRAM: Yes (LPDDR4 cache)
- TBW: 300TB
- Warranty: 5 years

**Where to buy:**
- **Amazon**: $45-55
- **Newegg**: $48-58
- **B&H Photo**: $50-60

**Alternatives:**
- **Budget**: Crucial P3: $38-45
  - DRAMless but good value
  - 3-year warranty
  
- **Performance**: Samsung 980 PRO: $75-95
  - PCIe 4.0 (overkill for this use)
  - 7,000 MB/s read
  
- **Value**: WD Blue SN570: $40-50
  - Good balance of price/performance
  - 5-year warranty

**Sizing guidance:**
- 256GB: Minimum for Basic tier
- 512GB: Recommended for Pro tier (system + containers)
- 1TB: For Premium tier or if running media server

### 3. eMMC Module - 32GB

**Why eMMC:**
- More reliable than microSD for boot
- Faster boot times
- Better endurance for OS writes
- Reduces wear on NVMe

**Specifications:**
- Capacity: 32GB
- Interface: eMMC 5.1
- Boot-capable: Yes
- Form factor: Orange Pi specific socket

**Where to buy:**
- **AliExpress - Orange Pi Official Store**: $15-25
  - Guaranteed compatibility
  - 16GB: $15
  - 32GB: $20
  - 64GB: $25 (overkill for boot)

**Alternative: microSD card**
- SanDisk Extreme 32GB: $10-15
- Works but less reliable long-term
- Slower boot times
- Use eMMC for production, SD for testing

### 4. Power Supply - 12V/3A

**Official Orange Pi adapter recommended**

**Why official:**
- Correct voltage regulation
- Adequate current rating
- Proper barrel connector size
- Safety certifications

**Specifications:**
- Input: 100-240V AC
- Output: 12V ⎓ 3A (36W)
- Connector: 5.5mm x 2.5mm barrel jack
- Cable length: 1.5m / 5ft

**Where to buy:**
- **AliExpress - Orange Pi Store**: $10-15
- **Amazon**: $12-18 (third-party)

**⚠️ Important:**
- Center positive polarity
- 3A minimum (5A recommended for stability)
- Don't use cheap adapters (can cause instability)

**Alternative:**
- Mean Well GST60A12-P1J: $18-25
  - Industrial quality
  - UL/CE certified
  - Highly reliable

### 5. Case with Cooling

**Recommended: Aluminum case with active cooling**

**Why:**
- Better heat dissipation
- Includes fan for active cooling
- Protection from physical damage
- EMI shielding

**Features to look for:**
- Full aluminum construction
- 40mm or larger fan
- Thermal pads included
- GPIO access (optional)
- VESA mount holes (optional)

**Where to buy:**
- **AliExpress**: $25-35
  - Search: "Orange Pi 5 Plus aluminum case"
  - Choose sellers with good reviews
  
**Specific recommendations:**
- Waveshare Metal Case: $30-35
  - High quality
  - Pre-installed thermal pads
  - 4010 fan included
  
- Generic aluminum: $20-28
  - Good value
  - May need to add thermal pads

**Alternative:**
- Acrylic case with fan: $15-20
  - Less heat dissipation
  - Good for testing/Basic tier

### 6. Network Switch

**Recommended: TP-Link TL-SG108E**

**Why:**
- Managed switch (VLAN support)
- Energy efficient
- Silent operation (fanless)
- Web management interface
- QoS support

**Specifications:**
- Ports: 8× Gigabit Ethernet
- Management: Web GUI
- VLANs: 802.1Q (32 groups)
- QoS: 802.1p
- Power: 4.9W max
- Mounting: Desktop or rack

**Where to buy:**
- **Amazon**: $40-50
- **Newegg**: $42-48
- **B&H Photo**: $45-52

**Alternatives:**

**Budget: TP-Link TL-SG105E** (5-port): $30-35
- Good for smaller setup
- Same features, fewer ports

**2.5GbE: NETGEAR MS108UP**: $110-140
- 8× 2.5GbE ports
- PoE+ support
- Better for future-proofing
- Consider for Premium tier

**10GbE: MikroTik CRS309-1G-8S+**: $300-350
- 8× 10G SFP+ ports
- Advanced routing
- Overkill for most home use

### 7. UPS - CyberPower CP800AVR

**Why UPS is critical:**
- Protects against power outages
- Prevents data corruption
- Graceful shutdown during extended outage
- Surge protection

**Specifications:**
- Capacity: 800VA / 450W
- Runtime: 10-20 minutes at full load
- Outlets: 4× battery backup + 4× surge only
- AVR: Automatic Voltage Regulation
- Management: USB monitoring
- Form factor: Tower

**Where to buy:**
- **Amazon**: $90-110
- **Best Buy**: $95-115
- **Newegg**: $92-108

**Alternatives:**

**Budget: APC BE600M1**: $65-80
- 600VA / 330W
- Good for Basic tier
- 6 outlets (3 battery, 3 surge)

**Premium: CyberPower CP1500PFCLCD**: $200-240
- 1500VA / 900W
- Pure sine wave (better for PSUs)
- LCD display
- Better for Premium tier

**Sizing guide:**
```
Power consumption estimate:
- 2× Orange Pi 5 Plus: 30-50W
- Network switch: 5-10W
- Margins: ×2 for safety
─────────────────────────────
Total: 100-150W typical

UPS should be 3-4× typical load
Recommended: 450W+ capacity
```

### 8. Accessories

**USB-to-TTL Serial Adapter:**
- CP2102 or FTDI: $5-12
- Essential for troubleshooting
- 3.3V logic level (important!)

**Thermal Management:**
- Arctic MX-4 4g: $8
- Thermal pads (if not included): $8-12
- Isopropyl alcohol 99%: $8

**Tools:**
- Phillips screwdriver set: $15-25
- Anti-static wrist strap: $5-10
- Cable tester: $15-25 (optional)

**Cable Management:**
- Velcro cable ties (50-pack): $8-12
- Cable labels: $10-15
- Heat shrink tubing: $10 (optional)

## Shopping Lists by Tier

### Basic Tier Shopping List

**Total: $165-204**

```
Amazon Cart:
□ Orange Pi 5 (8GB) - $95
□ 256GB NVMe SSD - $28
□ 32GB microSD card - $10
□ Metal case with fan - $18
□ 12V/2A power supply - $12
□ Cat6 cable (2-pack) - $10

Optional:
□ USB-TTL serial adapter - $8
```

### Pro Tier Shopping List

**Total: $730-890**

```
AliExpress Cart (Week 1 - Long shipping):
□ 2× Orange Pi 5 Plus (16GB) @ $165 = $330
□ 2× 32GB eMMC module @ $20 = $40
□ 2× Official 12V/3A PSU @ $13 = $26
□ 2× Aluminum case with fan @ $30 = $60

Amazon Cart (Week 2 - Fast shipping):
□ 2× Samsung 970 EVO Plus 512GB @ $50 = $100
□ TP-Link TL-SG108E switch - $45
□ CyberPower CP800AVR UPS - $95
□ Cat6 cables (5-pack) - $15
□ Belkin surge protector - $15
□ Anti-static wrist strap - $7
□ Arctic MX-4 thermal paste - $8
□ Velcro cable ties - $10
```

### Premium Tier Shopping List (N100)

**Total: $1,440-2,150**

```
Amazon Cart:
□ 2× ACEMAGIC N100 16GB/512GB @ $210 = $420
□ 2× Samsung 980 PRO 1TB @ $100 = $200
□ TerraMaster F4-424 NAS - $450
□ 4× WD Red Plus 4TB @ $100 = $400
□ NETGEAR MS108UP 2.5GbE switch - $120
□ APC BR1500G UPS - $185
□ 6U wall-mount rack - $75
□ Cat6A cables (10-pack) - $30
□ Cable management kit - $25
```

## Sourcing Strategy

### Timeline Approach

**Week 1: Order long-lead items**
- Order from AliExpress (15-30 day shipping)
- Orange Pi boards
- Cases and cooling
- Official accessories

**Week 2: Order fast-ship items**
- Order from Amazon (2-day shipping)
- Storage (SSDs, NAS drives)
- Networking equipment
- UPS and power
- Tools and accessories

**Week 3: Assembly**
- AliExpress items arrive
- Begin hardware assembly
- Test individual nodes

**Week 4: Deployment**
- Complete assembly
- Software deployment
- Testing and validation

### Cost Optimization Tips

**Save 10-20%:**
- Buy during sales (Prime Day, Black Friday)
- Use cashback services (Rakuten, TopCashback)
- Check for open-box items on Newegg
- Bundle purchases for free shipping

**Avoid:**
- Unknown sellers on AliExpress (stick to official stores)
- Too-cheap SSDs (often fake capacity)
- Unbranded power supplies (fire hazard)
- Super cheap cases (poor thermal performance)

## Warranty & Support

### Component Warranties

| Component | Warranty Period | Notes |
|-----------|----------------|-------|
| Orange Pi 5 Plus | 12 months | Through seller |
| Samsung 970 EVO Plus | 5 years | Direct with Samsung |
| Power Supply | 12 months | Orange Pi official |
| UPS | 3 years | CyberPower standard |
| Network Switch | Lifetime | TP-Link limited |

### Return Windows

- Amazon: 30 days (Prime)
- Newegg: 30 days (restocking fee may apply)
- AliExpress: 15 days (buyer protection)
- B&H Photo: 30 days

**Tips:**
- Test immediately upon receipt
- Keep all original packaging
- Document any issues with photos
- File claims within return window

## Import Considerations

### AliExpress Shipping

**Standard Shipping:**
- Cost: Free or $5-15
- Time: 15-30 days
- Tracking: Yes
- Duties: Usually included

**Express Shipping:**
- Cost: $20-40
- Time: 7-12 days
- Tracking: Full tracking
- Duties: May be separate

**Duties & Taxes:**
- US: Typically included in price
- EU: VAT may be separate
- UK: Post-Brexit duties apply
- Check your country's import limits

### Local Alternatives

**United States:**
- Micro Center (in-store pickup)
- Local electronics distributors

**Europe:**
- Reichelt Elektronik (Germany)
- Pimoroni (UK)
- Kubii (France)

**Asia:**
- Taobao (China)
- Tokopedia (Indonesia)
- Lazada (Southeast Asia)

## Quality Verification

### Upon Receipt Checklist

**Orange Pi Boards:**
```
□ No physical damage
□ All ports present and straight
□ No burned components
□ Serial number matches
□ Includes any promised accessories
□ Powers on (test immediately)
```

**Storage (NVMe/eMMC):**
```
□ Sealed packaging
□ Serial number verifiable
□ Correct capacity (verify with tools)
□ SMART data shows 0 power-on hours
□ No physical damage
```

**Power Supplies:**
```
□ Correct voltage and current rating
□ Proper connector size
□ No damage to cable or plug
□ Safety certifications present
□ Test with multimeter
```

**Networking:**
```
□ Sealed in original packaging
□ No damage to ports
□ Powers on correctly
□ All LEDs functional
□ Management interface accessible
```

### Testing Procedure

1. **Visual inspection** - Check for damage
2. **Verify specifications** - Match against order
3. **Basic power test** - Boot and check POST
4. **Stress test** - Run for 24 hours
5. **Performance test** - Benchmark storage/network
6. **Documentation** - Record serial numbers, photos

**Tools for verification:**
```bash
# Check NVMe health
nvme smart-log /dev/nvme0n1

# Verify capacity
lsblk
df -h

# Test speeds
fio --name=test --rw=write --bs=1M --size=1G

# Check RAM
free -h
cat /proc/meminfo

# Verify CPU
lscpu
cat /proc/cpuinfo
```

## Appendix: Part Numbers

### Quick Reference

| Component | Manufacturer Part # | Common Aliases |
|-----------|---------------------|----------------|
| Orange Pi 5 Plus 16GB | OPI5-PLUS-16GB | ORANGEPI-5-PLUS |
| Samsung 970 EVO Plus 500GB | MZ-V7S500BW | 970-EVO-PLUS-500 |
| TP-Link TL-SG108E | TL-SG108E v6 | SG108E |
| CyberPower CP800AVR | CP800AVR | CP-800-AVR |
| Arctic MX-4 | MX-4 2019 | ACTCP00002B |

### Size/Compatibility Chart

**M.2 NVMe Compatibility:**
- Form factor: 2280 (22mm × 80mm)
- Interface: M-Key (PCIe)
- Protocol: NVMe 1.3/1.4
- Not compatible: M.2 SATA SSDs

**Power Connector:**
- Barrel jack: 5.5mm × 2.5mm
- Polarity: Center positive
- Voltage: 12V DC
- Current: 3A minimum

**Case Compatibility:**
- Board: Orange Pi 5 Plus
- Not compatible: Orange Pi 5 (different layout)
- Check seller specifications

## Revision History

- v1.0 (2024-11-18): Initial BOM for Pro Tier
- Links will be updated periodically as availability changes

## Notes

- Prices fluctuate - check current pricing
- Availability varies by region
- Consider alternatives if items unavailable
- Join Orange Pi community for deals/tips
- Subscribe to price tracking (CamelCamelCamel for Amazon)
