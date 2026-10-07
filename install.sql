-- nk_bodyguard: Bodyguard Agency contracts (also created automatically on resource start)
CREATE TABLE IF NOT EXISTS `nk_bodyguard_contracts` (
    `id`         INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(80) NOT NULL,
    `name`       VARCHAR(40) NOT NULL,
    `tier`       VARCHAR(20) NOT NULL,
    `model`      VARCHAR(60) NOT NULL,
    `weapon`     VARCHAR(60) NOT NULL,
    `kills`      INT NOT NULL DEFAULT 0,
    `price`      INT NOT NULL DEFAULT 0,
    `status`     VARCHAR(12) NOT NULL DEFAULT 'active',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ended_at`   TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_owner_status` (`identifier`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
