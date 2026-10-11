-- =====================================================================
-- FreshTrace : ONE-FILE SETUP for the cloud database (or a fresh laptop)
-- Run ONCE with the lightning button. It builds everything:
-- tables, sample data, your own extra rows, 5 views, recall tracking.
-- =====================================================================
DROP DATABASE IF EXISTS freshtrace;
CREATE DATABASE freshtrace CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE freshtrace;
CREATE TABLE supplier (
  supplier_id INT AUTO_INCREMENT PRIMARY KEY, supplier_name VARCHAR(100) NOT NULL,
  fssai_licence_no CHAR(14) NOT NULL UNIQUE, city VARCHAR(50) NOT NULL, state VARCHAR(50) NOT NULL,
  phone VARCHAR(15) NOT NULL UNIQUE, email VARCHAR(100) UNIQUE, onboarded_on DATE NOT NULL DEFAULT (CURRENT_DATE),
  CONSTRAINT chk_fssai_len CHECK (CHAR_LENGTH(fssai_licence_no) = 14));
CREATE TABLE raw_material (
  material_id INT AUTO_INCREMENT PRIMARY KEY, material_name VARCHAR(60) NOT NULL UNIQUE,
  category VARCHAR(40) NOT NULL, unit VARCHAR(5) NOT NULL, storage_type VARCHAR(10) NOT NULL DEFAULT 'AMBIENT',
  CONSTRAINT chk_unit CHECK (unit IN ('kg','L')),
  CONSTRAINT chk_storage CHECK (storage_type IN ('AMBIENT','CHILLED','FROZEN')));
CREATE TABLE product (
  product_id INT AUTO_INCREMENT PRIMARY KEY, product_name VARCHAR(80) NOT NULL UNIQUE,
  category VARCHAR(40) NOT NULL, shelf_life_days INT NOT NULL, mrp DECIMAL(8,2) NOT NULL,
  CONSTRAINT chk_shelf CHECK (shelf_life_days > 0), CONSTRAINT chk_mrp CHECK (mrp > 0));
CREATE TABLE retailer (
  retailer_id INT AUTO_INCREMENT PRIMARY KEY, retailer_name VARCHAR(100) NOT NULL,
  retailer_type VARCHAR(12) NOT NULL DEFAULT 'KIRANA', city VARCHAR(50) NOT NULL, phone VARCHAR(15) NOT NULL UNIQUE,
  CONSTRAINT chk_rtype CHECK (retailer_type IN ('KIRANA','SUPERMARKET','HOTEL','DISTRIBUTOR')));
CREATE TABLE material_lot (
  lot_id INT AUTO_INCREMENT PRIMARY KEY, lot_code VARCHAR(20) NOT NULL UNIQUE, supplier_id INT NOT NULL,
  material_id INT NOT NULL, received_date DATE NOT NULL, expiry_date DATE NOT NULL,
  qty_received DECIMAL(10,2) NOT NULL, unit_cost DECIMAL(10,2) NOT NULL, lot_status VARCHAR(12) NOT NULL DEFAULT 'ACTIVE',
  CONSTRAINT fk_lot_supplier FOREIGN KEY (supplier_id) REFERENCES supplier(supplier_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_lot_material FOREIGN KEY (material_id) REFERENCES raw_material(material_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_lot_dates CHECK (expiry_date > received_date), CONSTRAINT chk_lot_qty CHECK (qty_received > 0),
  CONSTRAINT chk_lot_cost CHECK (unit_cost > 0),
  CONSTRAINT chk_lot_status CHECK (lot_status IN ('ACTIVE','QUARANTINED','REJECTED','RECALLED','CONSUMED')));
CREATE TABLE lot_inspection (
  inspection_id INT AUTO_INCREMENT PRIMARY KEY, lot_id INT NOT NULL, inspection_date DATE NOT NULL,
  parameter VARCHAR(40) NOT NULL, measured_value VARCHAR(30), result VARCHAR(4) NOT NULL, inspector_name VARCHAR(60) NOT NULL,
  CONSTRAINT fk_insp_lot FOREIGN KEY (lot_id) REFERENCES material_lot(lot_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_insp_result CHECK (result IN ('PASS','FAIL')));
CREATE TABLE production_batch (
  batch_id INT AUTO_INCREMENT PRIMARY KEY, batch_code VARCHAR(20) NOT NULL UNIQUE, product_id INT NOT NULL,
  mfg_date DATE NOT NULL, units_produced INT NOT NULL, batch_status VARCHAR(10) NOT NULL DEFAULT 'IN_QC',
  CONSTRAINT fk_batch_product FOREIGN KEY (product_id) REFERENCES product(product_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_batch_units CHECK (units_produced > 0),
  CONSTRAINT chk_batch_status CHECK (batch_status IN ('IN_QC','RELEASED','ON_HOLD','RECALLED')));
CREATE TABLE batch_ingredient (
  batch_id INT NOT NULL, lot_id INT NOT NULL, qty_used DECIMAL(10,2) NOT NULL, PRIMARY KEY (batch_id, lot_id),
  CONSTRAINT fk_bi_batch FOREIGN KEY (batch_id) REFERENCES production_batch(batch_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_bi_lot FOREIGN KEY (lot_id) REFERENCES material_lot(lot_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_bi_qty CHECK (qty_used > 0));
CREATE TABLE batch_qc_test (
  qc_id INT AUTO_INCREMENT PRIMARY KEY, batch_id INT NOT NULL, test_date DATE NOT NULL, test_type VARCHAR(40) NOT NULL,
  result VARCHAR(4) NOT NULL, remarks VARCHAR(200),
  CONSTRAINT fk_qc_batch FOREIGN KEY (batch_id) REFERENCES production_batch(batch_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_qc_result CHECK (result IN ('PASS','FAIL')));
CREATE TABLE shipment (
  shipment_id INT AUTO_INCREMENT PRIMARY KEY, batch_id INT NOT NULL, retailer_id INT NOT NULL, ship_date DATE NOT NULL,
  units_shipped INT NOT NULL, delivery_status VARCHAR(10) NOT NULL DEFAULT 'DISPATCHED',
  CONSTRAINT fk_ship_batch FOREIGN KEY (batch_id) REFERENCES production_batch(batch_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ship_retailer FOREIGN KEY (retailer_id) REFERENCES retailer(retailer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_ship_units CHECK (units_shipped > 0),
  CONSTRAINT chk_ship_status CHECK (delivery_status IN ('DISPATCHED','DELIVERED','RETURNED')));
CREATE TABLE recall (
  recall_id INT AUTO_INCREMENT PRIMARY KEY, lot_id INT NOT NULL UNIQUE, recall_date DATE NOT NULL,
  reason VARCHAR(200) NOT NULL, severity VARCHAR(6) NOT NULL, recall_status VARCHAR(6) NOT NULL DEFAULT 'OPEN',
  CONSTRAINT fk_recall_lot FOREIGN KEY (lot_id) REFERENCES material_lot(lot_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_recall_sev CHECK (severity IN ('HIGH','MEDIUM','LOW')),
  CONSTRAINT chk_recall_status CHECK (recall_status IN ('OPEN','CLOSED')));

-- =====================================================================
-- FreshTrace : 02_insert_data.sql
-- SAMPLE DATA — fictional companies, people, phone numbers and licence
-- numbers. Prices and test values are illustrative, not official limits.
-- Run AFTER 01_create_tables.sql. Insert order = parents first.
-- =====================================================================


-- SUPPLIERS (10) — fictional firms placed in real Indian spice/commodity hubs. Supplier 10 is newly onboarded and has no lots yet.
INSERT INTO supplier (supplier_id, supplier_name, fssai_licence_no, city, state, phone, email, onboarded_on) VALUES
  (1, 'Erode Haldi Traders', '12423008000137', 'Erode', 'Tamil Nadu', '9443102871', 'orders@erodehaldi.example', '2025-11-04'),
  (2, 'Krishna Turmeric Co.', '11523019000462', 'Sangli', 'Maharashtra', '9822416093', 'sales@krishnaturmeric.example', '2026-02-17'),
  (3, 'Guntur Mirchi Exports', '10123004000958', 'Guntur', 'Andhra Pradesh', '9848031527', 'info@gunturmirchi.example', '2025-12-09'),
  (4, 'Unjha Jeera Mandi Traders', '10723011000214', 'Unjha', 'Gujarat', '9825570348', 'jeera@unjhamandi.example', '2025-10-21'),
  (5, 'Hadoti Dhania Suppliers', '12223026000781', 'Ramganj Mandi', 'Rajasthan', '9414288135', 'hadoti.dhania@example.com', '2026-01-13'),
  (6, 'Malabar Pepper House', '11323017000590', 'Kochi', 'Kerala', '9447150962', 'trade@malabarpepper.example', '2025-09-30'),
  (7, 'Braj Kachi Ghani Oils', '12223031000346', 'Bharatpur', 'Rajasthan', '9460372418', 'braj.oils@example.com', '2026-03-02'),
  (8, 'Annapurna Chakki Atta', '12723042000127', 'Hapur', 'Uttar Pradesh', '9837264150', 'annapurna.atta@example.com', '2026-04-18'),
  (9, 'Kutch Salt Works', '10723055000863', 'Gandhidham', 'Gujarat', '9879014627', 'kutchsalt@example.com', '2025-08-11'),
  (10, 'Nilgiri Spice Collective', '12423060000415', 'Ooty', 'Tamil Nadu', '9488217306', 'hello@nilgirispice.example', '2026-10-01');

-- RAW MATERIALS (8)
INSERT INTO raw_material (material_id, material_name, category, unit, storage_type) VALUES
  (1, 'Turmeric Powder', 'Spice', 'kg', 'AMBIENT'),
  (2, 'Red Chilli Powder', 'Spice', 'kg', 'AMBIENT'),
  (3, 'Cumin Seeds', 'Spice', 'kg', 'AMBIENT'),
  (4, 'Coriander Seeds', 'Spice', 'kg', 'AMBIENT'),
  (5, 'Black Pepper', 'Spice', 'kg', 'AMBIENT'),
  (6, 'Mustard Oil', 'Edible Oil', 'L', 'AMBIENT'),
  (7, 'Wheat Flour', 'Grain', 'kg', 'AMBIENT'),
  (8, 'Iodised Salt', 'Salt', 'kg', 'AMBIENT');

-- PRODUCTS (6)
INSERT INTO product (product_id, product_name, category, shelf_life_days, mrp) VALUES
  (1, 'Haldi Powder 200g', 'Single Spice', 365, 62.0),
  (2, 'Lal Mirch Powder 200g', 'Single Spice', 365, 78.0),
  (3, 'Garam Masala 100g', 'Blended Masala', 365, 85.0),
  (4, 'Sambar Masala 100g', 'Blended Masala', 300, 70.0),
  (5, 'Chana Masala 100g', 'Blended Masala', 300, 72.0),
  (6, 'Masala Mathri 200g', 'Snack', 90, 55.0);

-- RETAILERS (12) — fictional Delhi NCR outlets. Retailer 12 was added recently and has received nothing yet.
INSERT INTO retailer (retailer_id, retailer_name, retailer_type, city, phone) VALUES
  (1, 'Sharma General Store', 'KIRANA', 'Ghaziabad', '9811402736'),
  (2, 'Gupta Kirana Bhandar', 'KIRANA', 'Ghaziabad', '9873015642'),
  (3, 'FreshMart Supermarket', 'SUPERMARKET', 'Noida', '8826104573'),
  (4, 'Aggarwal Provision Store', 'KIRANA', 'Delhi', '9810576214'),
  (5, 'Daily Needs Superstore', 'SUPERMARKET', 'Gurugram', '9654038127'),
  (6, 'Hotel Saffron Residency', 'HOTEL', 'Noida', '7042183659'),
  (7, 'NCR Spice Distributors', 'DISTRIBUTOR', 'Faridabad', '9899241705'),
  (8, 'Singh Brothers Grocery', 'KIRANA', 'Delhi', '9711630482'),
  (9, 'GreenLeaf Hypermart', 'SUPERMARKET', 'Gurugram', '8130547291'),
  (10, 'Bansal Traders', 'DISTRIBUTOR', 'Ghaziabad', '9958217043'),
  (11, 'Hotel Rajdhani Inn', 'HOTEL', 'Delhi', '9312780564'),
  (12, 'Verma Kirana Store', 'KIRANA', 'Faridabad', '9540361872');

-- MATERIAL LOTS (27). Lot 2 = contaminated turmeric (Sangli). Supplier 3 (Guntur) is the weak supplier.
INSERT INTO material_lot (lot_id, lot_code, supplier_id, material_id, received_date, expiry_date, qty_received, unit_cost, lot_status) VALUES
  (1, 'LT-TUR-2606-01', 1, 1, '2026-06-08', '2027-06-08', 980, 181.74, 'CONSUMED'),
  (2, 'LT-TUR-2607-01', 2, 1, '2026-07-02', '2027-07-02', 940, 157.18, 'RECALLED'),
  (3, 'LT-TUR-2608-01', 1, 1, '2026-08-05', '2027-08-05', 910, 169.04, 'ACTIVE'),
  (4, 'LT-TUR-2609-01', 2, 1, '2026-09-03', '2027-09-03', 660, 177.17, 'ACTIVE'),
  (5, 'LT-CHL-2606-01', 3, 2, '2026-06-10', '2027-06-10', 890, 231.25, 'RECALLED'),
  (6, 'LT-CHL-2606-02', 3, 2, '2026-06-20', '2027-06-20', 870, 242.59, 'CONSUMED'),
  (7, 'LT-CHL-2607-01', 3, 2, '2026-07-01', '2027-07-01', 760, 214.44, 'REJECTED'),
  (8, 'LT-CHL-2607-02', 3, 2, '2026-07-20', '2027-07-20', 720, 257.46, 'ACTIVE'),
  (9, 'LT-CHL-2608-01', 3, 2, '2026-08-12', '2027-08-12', 880, 227.5, 'REJECTED'),
  (10, 'LT-CHL-2609-01', 3, 2, '2026-09-08', '2027-09-08', 600, 248.25, 'QUARANTINED'),
  (11, 'LT-CUM-2606-01', 4, 3, '2026-06-12', '2027-06-12', 310, 298.33, 'CONSUMED'),
  (12, 'LT-CUM-2608-01', 4, 3, '2026-08-01', '2027-08-01', 410, 264.37, 'ACTIVE'),
  (13, 'LT-CUM-2609-01', 4, 3, '2026-09-14', '2027-09-14', 410, 293.83, 'ACTIVE'),
  (14, 'LT-COR-2606-01', 5, 4, '2026-06-09', '2027-04-05', 990, 116.7, 'ACTIVE'),
  (15, 'LT-COR-2607-01', 5, 4, '2026-07-15', '2027-05-11', 790, 95.31, 'ACTIVE'),
  (16, 'LT-COR-2608-01', 5, 4, '2026-08-25', '2027-06-21', 900, 88.92, 'ACTIVE'),
  (17, 'LT-PEP-2606-01', 6, 5, '2026-06-15', '2027-12-07', 220, 677.57, 'CONSUMED'),
  (18, 'LT-PEP-2608-01', 6, 5, '2026-08-18', '2028-02-09', 290, 619.95, 'ACTIVE'),
  (19, 'LT-MUS-2606-01', 7, 6, '2026-06-20', '2027-03-17', 420, 150.89, 'CONSUMED'),
  (20, 'LT-MUS-2608-01', 7, 6, '2026-08-10', '2027-05-07', 640, 150.0, 'ACTIVE'),
  (21, 'LT-MUS-2609-01', 7, 6, '2026-09-21', '2027-06-18', 690, 144.27, 'ACTIVE'),
  (22, 'LT-FLR-2607-01', 8, 7, '2026-07-06', '2026-10-04', 1830, 34.11, 'CONSUMED'),
  (23, 'LT-FLR-2608-01', 8, 7, '2026-08-03', '2026-11-01', 1930, 31.59, 'ACTIVE'),
  (24, 'LT-FLR-2608-02', 8, 7, '2026-08-31', '2026-11-29', 2210, 30.2, 'ACTIVE'),
  (25, 'LT-FLR-2609-01', 8, 7, '2026-09-28', '2026-12-27', 2400, 34.71, 'ACTIVE'),
  (26, 'LT-SLT-2606-01', 9, 8, '2026-06-18', '2028-06-17', 350, 12.76, 'ACTIVE'),
  (27, 'LT-SLT-2609-01', 9, 8, '2026-09-01', '2028-08-31', 400, 12.47, 'ACTIVE');

-- LOT INSPECTIONS
INSERT INTO lot_inspection (lot_id, inspection_date, parameter, measured_value, result, inspector_name) VALUES
  (1, '2026-06-08', 'Moisture (%)', '7.2%', 'PASS', 'R. Menon'),
  (14, '2026-06-09', 'Moisture (%)', '7.8%', 'PASS', 'R. Menon'),
  (5, '2026-06-10', 'Moisture (%)', '8.1%', 'PASS', 'R. Menon'),
  (5, '2026-06-10', 'Sudan dye screen', 'Absent', 'PASS', 'A. Rawat'),
  (11, '2026-06-12', 'Moisture (%)', '8.6%', 'PASS', 'R. Menon'),
  (17, '2026-06-15', 'Moisture (%)', '9.3%', 'PASS', 'P. Bhatt'),
  (26, '2026-06-18', 'Iodine content (ppm)', '20', 'PASS', 'A. Rawat'),
  (1, '2026-06-19', 'Lead (Pb) lab test', '0.6 mg/kg', 'PASS', 'S. Qureshi'),
  (6, '2026-06-21', 'Moisture (%)', '8.6%', 'PASS', 'R. Menon'),
  (6, '2026-06-21', 'Sudan dye screen', 'Absent', 'PASS', 'P. Bhatt'),
  (19, '2026-06-21', 'Argemone oil test', 'Absent', 'PASS', 'R. Menon'),
  (7, '2026-07-01', 'Moisture (%)', '13.6%', 'FAIL', 'R. Menon'),
  (7, '2026-07-01', 'Sudan dye screen', 'Absent', 'PASS', 'S. Qureshi'),
  (2, '2026-07-02', 'Moisture (%)', '8.5%', 'PASS', 'R. Menon'),
  (22, '2026-07-06', 'Moisture (%)', '11.7%', 'PASS', 'S. Qureshi'),
  (15, '2026-07-15', 'Moisture (%)', '8.7%', 'PASS', 'R. Menon'),
  (8, '2026-07-21', 'Moisture (%)', '8.0%', 'PASS', 'A. Rawat'),
  (8, '2026-07-21', 'Sudan dye screen', 'Absent', 'PASS', 'P. Bhatt'),
  (8, '2026-07-21', 'Aflatoxin screen', 'Within limit', 'PASS', 'S. Qureshi'),
  (12, '2026-08-01', 'Moisture (%)', '9.3%', 'PASS', 'R. Menon'),
  (23, '2026-08-04', 'Moisture (%)', '11.9%', 'PASS', 'P. Bhatt'),
  (3, '2026-08-05', 'Moisture (%)', '8.1%', 'PASS', 'P. Bhatt'),
  (20, '2026-08-10', 'Argemone oil test', 'Absent', 'PASS', 'R. Menon'),
  (9, '2026-08-13', 'Moisture (%)', '8.7%', 'PASS', 'R. Menon'),
  (9, '2026-08-13', 'Sudan dye screen', 'Detected', 'FAIL', 'R. Menon'),
  (3, '2026-08-14', 'Lead (Pb) lab test', '0.4 mg/kg', 'PASS', 'P. Bhatt'),
  (5, '2026-08-18', 'Sudan dye lab confirmation', 'Detected', 'FAIL', 'A. Rawat'),
  (18, '2026-08-19', 'Moisture (%)', '9.3%', 'PASS', 'P. Bhatt'),
  (16, '2026-08-25', 'Moisture (%)', '9.4%', 'PASS', 'A. Rawat'),
  (24, '2026-08-31', 'Moisture (%)', '12.1%', 'PASS', 'R. Menon'),
  (27, '2026-09-01', 'Iodine content (ppm)', '23', 'PASS', 'R. Menon'),
  (4, '2026-09-03', 'Moisture (%)', '9.4%', 'PASS', 'P. Bhatt'),
  (10, '2026-09-08', 'Moisture (%)', '12.4%', 'FAIL', 'R. Menon'),
  (10, '2026-09-08', 'Sudan dye screen', 'Absent', 'PASS', 'A. Rawat'),
  (4, '2026-09-12', 'Lead (Pb) lab test', '0.7 mg/kg', 'PASS', 'P. Bhatt'),
  (13, '2026-09-15', 'Moisture (%)', '9.7%', 'PASS', 'S. Qureshi'),
  (21, '2026-09-21', 'Argemone oil test', 'Absent', 'PASS', 'A. Rawat'),
  (25, '2026-09-28', 'Moisture (%)', '13.0%', 'PASS', 'R. Menon'),
  (2, '2026-10-05', 'Lead (Pb) lab test', '4.8 mg/kg', 'FAIL', 'A. Rawat');

-- PRODUCTION BATCHES (16)
INSERT INTO production_batch (batch_id, batch_code, product_id, mfg_date, units_produced, batch_status) VALUES
  (1, 'B-HLD-2606-01', 1, '2026-06-22', 2500, 'RELEASED'),
  (2, 'B-MRC-2606-01', 2, '2026-06-24', 2200, 'RECALLED'),
  (3, 'B-GRM-2606-01', 3, '2026-06-29', 3000, 'RELEASED'),
  (4, 'B-MRC-2607-01', 2, '2026-07-03', 2000, 'RELEASED'),
  (5, 'B-MTH-2607-01', 6, '2026-07-08', 4000, 'RELEASED'),
  (6, 'B-CHN-2607-01', 5, '2026-07-10', 3200, 'RELEASED'),
  (7, 'B-HLD-2607-01', 1, '2026-07-14', 2600, 'RECALLED'),
  (8, 'B-SMB-2607-01', 4, '2026-07-16', 3000, 'RECALLED'),
  (9, 'B-CHN-2607-02', 5, '2026-07-22', 2800, 'RECALLED'),
  (10, 'B-MTH-2608-01', 6, '2026-08-06', 4200, 'RELEASED'),
  (11, 'B-GRM-2608-01', 3, '2026-08-21', 3200, 'RELEASED'),
  (12, 'B-MRC-2608-01', 2, '2026-08-24', 2400, 'ON_HOLD'),
  (13, 'B-MTH-2609-01', 6, '2026-09-02', 4000, 'RELEASED'),
  (14, 'B-HLD-2609-01', 1, '2026-09-07', 2400, 'RELEASED'),
  (15, 'B-SMB-2609-01', 4, '2026-09-16', 3000, 'RELEASED'),
  (16, 'B-CHN-2610-01', 5, '2026-10-07', 3000, 'IN_QC');

-- BATCH INGREDIENTS (M:N batch-lot, quantities in kg/L)
INSERT INTO batch_ingredient (batch_id, lot_id, qty_used) VALUES
  (1, 1, 510.0),
  (2, 5, 448.8),
  (3, 11, 107.1),
  (3, 14, 107.1),
  (3, 17, 91.8),
  (4, 6, 408.0),
  (5, 11, 24.48),
  (5, 19, 163.2),
  (5, 22, 603.84),
  (5, 26, 24.48),
  (6, 1, 32.64),
  (6, 6, 81.6),
  (6, 11, 65.28),
  (6, 14, 114.24),
  (6, 17, 32.64),
  (7, 1, 437.36),
  (7, 2, 93.04),
  (8, 2, 30.6),
  (8, 6, 76.5),
  (8, 11, 45.9),
  (8, 14, 122.4),
  (8, 17, 30.6),
  (9, 2, 28.56),
  (9, 6, 71.4),
  (9, 11, 57.12),
  (9, 14, 99.96),
  (9, 17, 28.56),
  (10, 11, 10.12),
  (10, 12, 15.58),
  (10, 19, 171.36),
  (10, 22, 634.03),
  (10, 26, 25.7),
  (11, 12, 114.24),
  (11, 14, 114.24),
  (11, 17, 36.4),
  (11, 18, 61.52),
  (12, 6, 232.5),
  (12, 8, 257.1),
  (13, 12, 24.48),
  (13, 19, 85.44),
  (13, 20, 77.76),
  (13, 22, 592.13),
  (13, 23, 11.71),
  (13, 26, 24.48),
  (14, 3, 489.6),
  (15, 3, 30.6),
  (15, 8, 76.5),
  (15, 12, 45.9),
  (15, 14, 122.4),
  (15, 18, 30.6),
  (16, 3, 30.6),
  (16, 8, 76.5),
  (16, 12, 61.2),
  (16, 14, 107.1),
  (16, 18, 30.6);

-- BATCH QC TESTS (latest batch has none yet: still IN_QC)
INSERT INTO batch_qc_test (batch_id, test_date, test_type, result, remarks) VALUES
  (1, '2026-06-24', 'Moisture (%)', 'PASS', NULL),
  (2, '2026-06-26', 'Moisture (%)', 'PASS', NULL),
  (2, '2026-06-26', 'Microbial count (TPC)', 'PASS', 'Within internal limit'),
  (3, '2026-07-01', 'Moisture (%)', 'PASS', NULL),
  (4, '2026-07-05', 'Moisture (%)', 'PASS', NULL),
  (5, '2026-07-10', 'Moisture (%)', 'PASS', NULL),
  (5, '2026-07-10', 'Sensory & packaging', 'PASS', NULL),
  (6, '2026-07-12', 'Moisture (%)', 'PASS', NULL),
  (7, '2026-07-16', 'Moisture (%)', 'PASS', NULL),
  (7, '2026-07-16', 'Microbial count (TPC)', 'PASS', 'Within internal limit'),
  (8, '2026-07-18', 'Moisture (%)', 'PASS', NULL),
  (8, '2026-07-18', 'Microbial count (TPC)', 'PASS', 'Within internal limit'),
  (9, '2026-07-24', 'Moisture (%)', 'PASS', NULL),
  (9, '2026-07-24', 'Microbial count (TPC)', 'PASS', 'Within internal limit'),
  (10, '2026-08-08', 'Moisture (%)', 'PASS', NULL),
  (10, '2026-08-08', 'Sensory & packaging', 'PASS', NULL),
  (11, '2026-08-23', 'Moisture (%)', 'PASS', NULL),
  (12, '2026-08-26', 'Moisture (%)', 'FAIL', 'Moisture 12.1% — batch held for re-drying'),
  (13, '2026-09-04', 'Moisture (%)', 'PASS', NULL),
  (13, '2026-09-04', 'Sensory & packaging', 'PASS', NULL),
  (14, '2026-09-09', 'Moisture (%)', 'PASS', NULL),
  (14, '2026-09-09', 'Microbial count (TPC)', 'PASS', 'Within internal limit'),
  (15, '2026-09-18', 'Moisture (%)', 'PASS', NULL);

-- SHIPMENTS
INSERT INTO shipment (batch_id, retailer_id, ship_date, units_shipped, delivery_status) VALUES
  (1, 1, '2026-06-26', 300, 'DELIVERED'),
  (1, 10, '2026-06-27', 1000, 'DELIVERED'),
  (2, 9, '2026-06-28', 450, 'RETURNED'),
  (2, 2, '2026-06-29', 350, 'DELIVERED'),
  (2, 7, '2026-06-30', 1000, 'DELIVERED'),
  (3, 4, '2026-07-03', 450, 'DELIVERED'),
  (1, 9, '2026-07-04', 200, 'DELIVERED'),
  (3, 9, '2026-07-06', 400, 'DELIVERED'),
  (2, 4, '2026-07-07', 350, 'DELIVERED'),
  (4, 1, '2026-07-07', 650, 'DELIVERED'),
  (4, 11, '2026-07-09', 350, 'DELIVERED'),
  (3, 8, '2026-07-11', 650, 'DELIVERED'),
  (3, 10, '2026-07-12', 600, 'DELIVERED'),
  (5, 10, '2026-07-12', 800, 'DELIVERED'),
  (4, 5, '2026-07-13', 650, 'DELIVERED'),
  (5, 6, '2026-07-14', 250, 'DELIVERED'),
  (6, 7, '2026-07-14', 600, 'DELIVERED'),
  (5, 8, '2026-07-16', 650, 'DELIVERED'),
  (5, 1, '2026-07-17', 200, 'DELIVERED'),
  (6, 2, '2026-07-18', 500, 'DELIVERED'),
  (7, 1, '2026-07-18', 400, 'DELIVERED'),
  (4, 3, '2026-07-19', 300, 'DELIVERED'),
  (7, 3, '2026-07-19', 400, 'DELIVERED'),
  (7, 4, '2026-07-20', 550, 'DELIVERED'),
  (8, 2, '2026-07-20', 450, 'DELIVERED'),
  (6, 6, '2026-07-22', 350, 'DELIVERED'),
  (8, 6, '2026-07-22', 300, 'DELIVERED'),
  (8, 5, '2026-07-23', 350, 'DELIVERED'),
  (9, 3, '2026-07-26', 400, 'DELIVERED'),
  (5, 4, '2026-07-27', 200, 'DELIVERED'),
  (9, 10, '2026-07-30', 800, 'DELIVERED'),
  (9, 7, '2026-07-31', 700, 'DELIVERED'),
  (10, 1, '2026-08-10', 550, 'DELIVERED'),
  (10, 10, '2026-08-12', 800, 'DELIVERED'),
  (10, 2, '2026-08-16', 550, 'DELIVERED'),
  (10, 8, '2026-08-18', 550, 'DELIVERED'),
  (11, 2, '2026-08-25', 650, 'DELIVERED'),
  (11, 5, '2026-08-27', 650, 'DELIVERED'),
  (11, 11, '2026-08-27', 200, 'DELIVERED'),
  (13, 11, '2026-09-06', 300, 'DELIVERED'),
  (13, 4, '2026-09-10', 650, 'DELIVERED'),
  (14, 4, '2026-09-11', 400, 'DELIVERED'),
  (13, 2, '2026-09-12', 600, 'DELIVERED'),
  (13, 8, '2026-09-14', 550, 'DELIVERED'),
  (14, 2, '2026-09-15', 250, 'DELIVERED'),
  (14, 7, '2026-09-20', 600, 'DELIVERED'),
  (15, 10, '2026-09-20', 1000, 'DELIVERED'),
  (14, 3, '2026-09-21', 600, 'DELIVERED'),
  (15, 8, '2026-09-22', 650, 'DELIVERED'),
  (15, 6, '2026-09-23', 650, 'DELIVERED');

-- RECALLS (2)
INSERT INTO recall (recall_id, lot_id, recall_date, reason, severity, recall_status) VALUES
  (1, 5, '2026-08-19', 'Lab confirmed Sudan dye in red chilli lot after gate screen was missed', 'MEDIUM', 'CLOSED'),
  (2, 2, '2026-10-06', 'Periodic lab test found lead (Pb) above internal limit in turmeric lot', 'HIGH', 'OPEN');

-- ---------------- your own rows (from 03_dml) ----------------
-- -- PART A : INSERT  (new supplier -> new lot -> its inspection)
-- Order matters: parent row first, child rows after (FK rule).
-- ---------------------------------------------------------------------

-- A1. A new coriander supplier joins.
--     onboarded_on is not given -> DEFAULT (CURRENT_DATE) fills today's date.
INSERT INTO supplier (supplier_id, supplier_name, fssai_licence_no, city, state, phone, email)
VALUES (11, 'Doaba Agro Spices', '12723071000294', 'Kota', 'Rajasthan', '9414630258', 'doaba.agro@example.com');
-- Expected: 1 row(s) affected

-- A2. Their first coriander lot arrives. lot_status not given -> DEFAULT 'ACTIVE'.
INSERT INTO material_lot (lot_id, lot_code, supplier_id, material_id, received_date, expiry_date, qty_received, unit_cost)
VALUES (28, 'LT-COR-2610-01', 11, 4, '2026-10-08', '2027-08-04', 650, 104.50);
-- Expected: 1 row(s) affected

-- A3. Gate inspection of that lot.
INSERT INTO lot_inspection (lot_id, inspection_date, parameter, measured_value, result, inspector_name)
VALUES (28, '2026-10-08', 'Moisture (%)', '8.6%', 'PASS', 'P. Bhatt');
-- Expected: 1 row(s) affected

-- A4. A new retailer near Ghaziabad, and two shipments to them (multi-row INSERT).
--     delivery_status not given -> DEFAULT 'DISPATCHED'.
INSERT INTO retailer (retailer_id, retailer_name, retailer_type, city, phone)
VALUES (13, 'Kavi Nagar Fresh Store', 'KIRANA', 'Ghaziabad', '9599127430');

INSERT INTO shipment (batch_id, retailer_id, ship_date, units_shipped) VALUES
  (14, 13, '2026-10-08', 300),   -- Haldi Powder, batch B-HLD-2609-01
  (15, 13, '2026-10-08', 250);   -- Sambar Masala, batch B-SMB-2609-01
-- Expected: 2 row(s) affected

SELECT * FROM shipment WHERE retailer_id = 13;
-- Expected: 2 rows, delivery_status = DISPATCHED (filled by DEFAULT)

-- ---------------------------------------------------------------------
-- PART B : UPDATE
-- ALWAYS write the WHERE clause. UPDATE without WHERE changes EVERY row.
-- ---------------------------------------------------------------------

-- B1. The Haldi shipment reached the shop.
UPDATE shipment
SET    delivery_status = 'DELIVERED'
WHERE  retailer_id = 13 AND batch_id = 14;
-- Expected: 1 row(s) affected

-- B2. Price revision: blended masalas go up by 5%.
UPDATE product
SET    mrp = ROUND(mrp * 1.05, 2)
WHERE  category = 'Blended Masala';
-- Expected: 3 row(s) affected  (Garam 85.00->89.25, Sambar 70.00->73.50, Chana 72.00->75.60)


-- =====================================================================
-- FreshTrace : 05_views.sql
-- A VIEW is a saved SELECT query with a name. It stores NO data of its own:
-- every time you query it, MySQL re-runs the SELECT on the live tables.
-- Run order: 01 -> 02 -> 03 -> (04 optional) -> THIS FILE.
-- Run each CREATE with Ctrl+Enter, then the SELECT under it.
-- =====================================================================


-- ---------------------------------------------------------------------
-- VIEW 1 : v_recall_impact            USER: recall officer
-- WHY    : the recall trace is an 8-table JOIN. Nobody should retype it
--          during an emergency. The view turns it into one simple SELECT,
--          and it includes shop phone numbers so the officer can call them.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_recall_impact AS
SELECT rc.recall_id,
       rc.recall_status,
       rc.severity,
       l.lot_code,
       s.supplier_name,
       b.batch_code,
       p.product_name,
       r.retailer_name,
       r.city,
       r.phone       AS retailer_phone,
       sh.ship_date,
       sh.units_shipped
FROM   recall rc
JOIN   material_lot     l  ON rc.lot_id     = l.lot_id
JOIN   supplier         s  ON l.supplier_id = s.supplier_id
JOIN   batch_ingredient bi ON bi.lot_id     = l.lot_id
JOIN   production_batch b  ON b.batch_id    = bi.batch_id
JOIN   product          p  ON p.product_id  = b.product_id
JOIN   shipment         sh ON sh.batch_id   = b.batch_id
JOIN   retailer         r  ON r.retailer_id = sh.retailer_id;

-- Use it: which Noida shops must be called for the OPEN recall?
SELECT retailer_name, retailer_phone, product_name, units_shipped
FROM   v_recall_impact
WHERE  recall_status = 'OPEN' AND city = 'Noida';
-- EXPECTED: 3 rows: FreshMart Supermarket (Haldi 400, Chana 400), Hotel Saffron Residency (Sambar 300)

-- ---------------------------------------------------------------------
-- VIEW 2 : v_supplier_scorecard       USER: procurement / purchase team
-- WHY    : decides whom to buy from next. Uses LEFT JOINs so EVERY supplier
--          appears, even new ones with no lots yet ('NO DATA').
--          Notice: NO phone numbers of retailers here - each team sees only
--          what it needs. That is how views support SECURITY.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_supplier_scorecard AS
SELECT s.supplier_id,
       s.supplier_name,
       s.city,
       COUNT(DISTINCT l.lot_id)                            AS lots_sent,
       COUNT(i.inspection_id)                              AS total_tests,
       SUM(CASE WHEN i.result = 'FAIL' THEN 1 ELSE 0 END)  AS failed_tests,
       ROUND(100 * SUM(CASE WHEN i.result = 'FAIL' THEN 1 ELSE 0 END)
                 / NULLIF(COUNT(i.inspection_id), 0), 1)   AS fail_percent,
       CASE
         WHEN COUNT(i.inspection_id) = 0 THEN 'NO DATA'
         WHEN 100 * SUM(CASE WHEN i.result = 'FAIL' THEN 1 ELSE 0 END)
                  / COUNT(i.inspection_id) >= 20 THEN 'HIGH RISK'
         WHEN SUM(CASE WHEN i.result = 'FAIL' THEN 1 ELSE 0 END) > 0 THEN 'WATCH'
         ELSE 'RELIABLE'
       END                                                 AS risk_band
FROM   supplier s
LEFT   JOIN material_lot   l ON l.supplier_id = s.supplier_id
LEFT   JOIN lot_inspection i ON i.lot_id      = l.lot_id
GROUP  BY s.supplier_id, s.supplier_name, s.city;

SELECT supplier_name, lots_sent, total_tests, failed_tests, fail_percent, risk_band
FROM   v_supplier_scorecard
ORDER  BY fail_percent DESC;
-- EXPECTED: 11 rows. Guntur 28.6 HIGH RISK, Krishna 25.0 HIGH RISK, 8 suppliers RELIABLE,
--           Nilgiri Spice Collective NO DATA (fail_percent NULL - it has no tests yet)
-- NULLIF(x,0) returns NULL when x = 0, which avoids a divide-by-zero.

-- ---------------------------------------------------------------------
-- VIEW 3 : v_lot_expiry_alert         USER: store / warehouse manager
-- WHY    : shows how much of each usable lot is LEFT and how soon it expires,
--          so old stock is used first (FEFO: First-Expiry-First-Out).
--          qty_left is CALCULATED, not stored - no risk of it going out of date.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_lot_expiry_alert AS
SELECT l.lot_code,
       m.material_name,
       s.supplier_name,
       l.expiry_date,
       DATEDIFF(l.expiry_date, CURDATE())                 AS days_left,
       l.qty_received - COALESCE(SUM(bi.qty_used), 0)     AS qty_left,
       CASE
         WHEN DATEDIFF(l.expiry_date, CURDATE()) < 0   THEN 'EXPIRED'
         WHEN DATEDIFF(l.expiry_date, CURDATE()) <= 30 THEN 'USE FIRST'
         WHEN DATEDIFF(l.expiry_date, CURDATE()) <= 90 THEN 'WATCH'
         ELSE 'OK'
       END                                                AS alert
FROM   material_lot l
JOIN   raw_material m ON m.material_id = l.material_id
JOIN   supplier     s ON s.supplier_id = l.supplier_id
LEFT   JOIN batch_ingredient bi ON bi.lot_id = l.lot_id
WHERE  l.lot_status = 'ACTIVE'
GROUP  BY l.lot_id, l.lot_code, m.material_name, s.supplier_name, l.expiry_date, l.qty_received;

SELECT * FROM v_lot_expiry_alert
WHERE  alert IN ('EXPIRED', 'USE FIRST', 'WATCH')
ORDER  BY days_left;
-- EXPECTED (on ~10 Oct 2026): 3 flour lots. LT-FLR-2608-01 USE FIRST (~22 days, ~1918 kg left),
--           LT-FLR-2608-02 and LT-FLR-2609-01 WATCH. Days shift by one each day.

-- ---------------------------------------------------------------------
-- VIEW 4 : v_batch_shelf_status       USER: sales / dispatch team
-- WHY    : batch expiry is a DERIVED value (mfg_date + shelf_life_days).
--          We chose NOT to store it (normalization), so this view computes it
--          once, in one place, for everybody.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_batch_shelf_status AS
SELECT b.batch_code,
       p.product_name,
       b.batch_status,
       b.mfg_date,
       DATE_ADD(b.mfg_date, INTERVAL p.shelf_life_days DAY)                       AS expiry_date,
       DATEDIFF(DATE_ADD(b.mfg_date, INTERVAL p.shelf_life_days DAY), CURDATE())  AS days_to_expiry,
       b.units_produced,
       COALESCE(SUM(sh.units_shipped), 0)                                         AS units_shipped,
       b.units_produced - COALESCE(SUM(sh.units_shipped), 0)                      AS units_in_factory
FROM   production_batch b
JOIN   product p ON p.product_id = b.product_id
LEFT   JOIN shipment sh ON sh.batch_id = b.batch_id
GROUP  BY b.batch_id, b.batch_code, p.product_name, b.batch_status, b.mfg_date,
          p.shelf_life_days, b.units_produced;

SELECT batch_code, product_name, batch_status, expiry_date, days_to_expiry, units_in_factory
FROM   v_batch_shelf_status
WHERE  days_to_expiry < 60
ORDER  BY days_to_expiry;
-- EXPECTED (on ~10 Oct 2026): 3 Masala Mathri batches: B-MTH-2607-01 already EXPIRED (negative days,
--           and 1900 units still in the factory!), B-MTH-2608-01 ~25 days, B-MTH-2609-01 ~52 days.

-- ---------------------------------------------------------------------
-- Handy commands
-- ---------------------------------------------------------------------
SHOW FULL TABLES WHERE Table_type = 'VIEW';    -- lists your 4 views
-- DROP VIEW v_batch_shelf_status;             -- removes a view (tables are NOT touched)

-- =====================================================================
-- FreshTrace : 06_recall_workflow.sql
-- Adds ONE new table so a recall can be TRACKED until it is finished.
-- Run once (Ctrl+Enter, top to bottom) AFTER all earlier files.
-- =====================================================================


-- ---------------------------------------------------------------------
-- RECALL_NOTICE : one row per (recall, shop)
--   Which shop must return how many units, has it been contacted,
--   and how many units have come back.
--   M:N bridge between RECALL and RETAILER  ->  composite primary key.
-- ---------------------------------------------------------------------
CREATE TABLE recall_notice (
  recall_id       INT         NOT NULL,
  retailer_id     INT         NOT NULL,
  units_to_return INT         NOT NULL,
  notified_on     DATE,                                  -- NULL = not contacted yet
  units_returned  INT         NOT NULL DEFAULT 0,
  notice_status   VARCHAR(10) NOT NULL DEFAULT 'PENDING',
  PRIMARY KEY (recall_id, retailer_id),
  CONSTRAINT fk_notice_recall   FOREIGN KEY (recall_id)
      REFERENCES recall(recall_id)     ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_notice_retailer FOREIGN KEY (retailer_id)
      REFERENCES retailer(retailer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_notice_units   CHECK (units_to_return > 0),
  CONSTRAINT chk_notice_return  CHECK (units_returned BETWEEN 0 AND units_to_return),
  CONSTRAINT chk_notice_status  CHECK (notice_status IN ('PENDING','CONTACTED','COLLECTED'))
);

-- ---------------------------------------------------------------------
-- Fill notices for the 2 recalls that already exist.
-- INSERT ... SELECT : the rows to insert come from a query.
-- Old (CLOSED) recall -> every shop already COLLECTED.
-- Current (OPEN) recall -> every shop still PENDING.
-- ---------------------------------------------------------------------
INSERT INTO recall_notice (recall_id, retailer_id, units_to_return, notified_on, units_returned, notice_status)
SELECT rc.recall_id,
       sh.retailer_id,
       SUM(sh.units_shipped),
       CASE WHEN rc.recall_status = 'CLOSED' THEN rc.recall_date END,
       CASE WHEN rc.recall_status = 'CLOSED' THEN SUM(sh.units_shipped) ELSE 0 END,
       CASE WHEN rc.recall_status = 'CLOSED' THEN 'COLLECTED' ELSE 'PENDING' END
FROM recall rc
JOIN batch_ingredient bi ON bi.lot_id   = rc.lot_id
JOIN shipment         sh ON sh.batch_id = bi.batch_id
GROUP BY rc.recall_id, sh.retailer_id, rc.recall_status, rc.recall_date;

SELECT * FROM recall_notice ORDER BY recall_id, retailer_id;
-- EXPECTED: 12 rows. Recall 1 (closed): 4 shops COLLECTED.
--           Recall 2 (open): 8 shops PENDING.

-- ---------------------------------------------------------------------
-- VIEW 5 : v_recall_progress   (how far along is each recall?)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_recall_progress AS
SELECT rc.recall_id, l.lot_code, rc.recall_status, rc.severity,
       COUNT(*)                                                    AS shops,
       SUM(CASE WHEN n.notice_status = 'COLLECTED' THEN 1 ELSE 0 END) AS shops_done,
       SUM(n.units_to_return)                                      AS units_to_return,
       SUM(n.units_returned)                                       AS units_returned,
       ROUND(100 * SUM(n.units_returned) / SUM(n.units_to_return), 1) AS percent_recovered
FROM recall rc
JOIN material_lot  l ON l.lot_id    = rc.lot_id
JOIN recall_notice n ON n.recall_id = rc.recall_id
GROUP BY rc.recall_id, l.lot_code, rc.recall_status, rc.severity;

SELECT * FROM v_recall_progress;
-- EXPECTED: recall 1 -> 4 of 4 shops, 100.0 %;  recall 2 -> 0 of 8 shops, 0.0 %
