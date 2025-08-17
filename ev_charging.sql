create database ev_charging;
use ev_charging;


create table Vehicles (
Vehicle_id int AUTO_INCREMENT primary key,
Owner_name varchar(50) not null,
Battery_capacity_kWh decimal(4,2) not null,
Current_soc_percent DECIMAL(5,2) check( current_soc_percent >= 0 and current_soc_percent <= 100)
);



create table ChargingSlots (
Slot_id int AUTO_INCREMENT primary key,
Status ENUM('Free','Occupied') NOT NULL DEFAULT 'Free',
Start_time TIME Not null ,
End_time TIME not null
);


create table Tariffs(
Tariff_id int AUTO_INCREMENT primary key,
Rate_per_kWh DECIMAL(6,2) NOT NULL ,
Valid_from date ,
Valid_to date 
);


create table ChargingRequests (
Request_id int AUTO_INCREMENT primary key,
Vehicle_id INT NOT NULL ,
Required_kWh decimal(4,2) NOT NULL ,
Requested_time TIME NOT NULL,
foreign key (Vehicle_id) references Vehicles(Vehicle_id)
);

SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE ChargingSlots;
TRUNCATE TABLE ChargingRequests;
TRUNCATE TABLE Vehicles;
TRUNCATE TABLE Tariffs;

SET FOREIGN_KEY_CHECKS = 1;


INSERT INTO Vehicles (Owner_name, Battery_capacity_kWh, Current_soc_percent) VALUES
('Alice Johnson', 75.00, 40.00),
('Bob Smith', 60.00, 85.50),
('Charlie Davis', 50.00, 25.00),
('Diana Brown', 90.00, 60.00),
('Ethan Wilson', 70.00, 10.00);



INSERT INTO ChargingSlots (Status, Start_time, End_time) VALUES
('Free', '08:00:00', '10:00:00'),
('Occupied', '10:00:00', '12:00:00'),
('Free', '12:00:00', '14:00:00'),
('Occupied', '14:00:00', '16:00:00'),
('Free', '16:00:00', '18:00:00');


INSERT INTO Tariffs (Rate_per_kWh, Valid_from, Valid_to) VALUES
(5.50, '2025-08-01', '2025-08-15'),
(6.00, '2025-08-16', '2025-08-31'),
(5.75, '2025-09-01', '2025-09-15');


INSERT INTO ChargingRequests (Vehicle_id, Required_kWh, Requested_time) VALUES
(1, 20.50, '08:15:00'),
(2, 10.00, '10:30:00'),
(3, 35.00, '12:45:00'),
(4, 15.75, '14:20:00'),
(5, 40.00, '16:10:00');




-- add Request_id to chargingslots
Alter table ChargingSlots 
add column Request_id int null,
add foreign key(Request_id) references ChargingRequests(Request_id);


SET SQL_SAFE_UPDATES = 0;
SET SQL_SAFE_UPDATES = 1;

select * FROM ChargingSlots;
-- total cost for charging
Select cr.Request_id,
cr.Vehicle_id,
cr.Required_kWh,
t.Rate_per_kWh,
(cr.Required_kWh * t.Rate_per_kWh) AS Total_Cost
from ChargingRequests cr 
join Tariffs t 
on current_date between t.Valid_from and t.Valid_to;

select v.Owner_name,
v.Vehicle_id,
cs.Start_time,
cs.End_time,
cr.Requested_time,
cr.Required_kWh,
t.Rate_per_kWh,
(cr.Required_kWh * t.Rate_per_kWh) as Cost
from ChargingSlots cs
join ChargingRequests cr on cs.Request_id = cr.Request_id
join Vehicles v on cr.Vehicle_id = v.Vehicle_id
join Tariffs t 
on current_date between t.Valid_from and t.Valid_to;

-- add status in ChargingRequest
alter table ChargingRequests
add column status enum('rejected','alloted','pending') default 'pending';

-- procedure to allocate slot and update request_id, status
DELIMITER $$
CREATE PROCEDURE AllocateChargingSlot(
    IN p_vehicle_id INT,
    in p_required_kWh decimal(4,2) ,
    IN p_requested_time TIME
)
BEGIN
    DECLARE v_slot_id INT;
    DECLARE v_request_id INT;
    DECLARE v_soc DECIMAL(5,2);

    START TRANSACTION;

    -- Step 1: Find a free slot
    SELECT Slot_id INTO v_slot_id
    FROM ChargingSlots
    WHERE p_requested_time BETWEEN Start_time AND End_time
      AND Status = 'Free'
    LIMIT 1;
    -- set  v-soc
    select Current_soc_percent into v_soc
    from Vehicles v
    where v.Vehicle_id = p_vehicle_id;
    
    IF v_soc >= 95 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'SUFFICIENT SOC';
    END IF;
    
    
    IF v_slot_id IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No free slot available at requested time.';
    END IF;

    -- Step 2: Insert charging request
    INSERT INTO ChargingRequests (Vehicle_id, Required_kWh, Requested_time,status)
    VALUES (p_vehicle_id, p_required_kWh , p_requested_time,'alloted'); 
    SET v_request_id = LAST_INSERT_ID();

    -- Step 3: Update slot status and link request
    UPDATE ChargingSlots
    SET Status = 'Occupied',
        Request_id = v_request_id
    WHERE Slot_id = v_slot_id;

    COMMIT;
END$$
DELIMITER ;

CALL AllocateChargingSlot(1, 20.50, '08:15:00');
select * from ChargingRequests;

-- cost column in requests
alter table ChargingRequests
add column cost decimal(10,2);




-- total cost 
DELIMITER $$
CREATE PROCEDURE total_cost(
IN p_request_id int,
OUT tariff_cost DECIMAL(10,2)
)
BEGIN
    DECLARE p_required_kWh DECIMAL(5,2);
    DECLARE t_rate_tariff DECIMAL(6,2);
    
    SELECT Required_kwh into p_required_kWh 
    from ChargingRequests
    WHERE Request_id = p_request_id;
    
    SELECT Rate_per_kWh into t_rate_tariff
    from Tariffs
    WHERE CURRENT_DATE BETWEEN Valid_from AND Valid_to;
    SET tariff_cost = p_required_kwh * t_rate_tariff;
    update ChargingRequests
    set cost = tariff_cost
    where Request_id = p_request_id;
    
END$$
DELIMITER ;


CALL total_cost(3, @cost);
select * from ChargingRequests
    
    
    
    
    















































