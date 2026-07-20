package org.opengroup.osdu.schema.util;

import org.opengroup.osdu.schema.constants.TestConstants;

public class TenantResolver {

    public static String resolveTenant(String tenant) {
        return switch (tenant) {
            case "TENANT1" -> TestConstants.privateTenant1();
            case "TENANT2" -> TestConstants.privateTenant2();
            case "COMMON"  -> TestConstants.sharedTenant();
            default        -> tenant;
        };
    }
}
