//
//  Config.swift.swift
//  Bits
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation
import PostgreSQL

let recurly = Recurly(subdomain: "\(env["RECURLY_SUBDOMAIN"]).recurly.com", apiKey: env["RECURLY_API_KEY"])

let postgresConfig = ConnInfo.params([
    "host": env[optional: "RDS_HOSTNAME"] ?? "localhost",
    "dbname": env[optional: "RDS_DB_NAME"] ?? "swifttalk_dev",
    "user": env[optional: "RDS_DB_USERNAME"] ?? "chris",
    "password": env[optional: "RDS_DB_PASSWORD"] ?? "",
    "connect_timeout": "1",
])
