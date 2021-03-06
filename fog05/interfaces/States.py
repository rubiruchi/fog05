# Copyright (c) 2014,2018 Contributors to the Eclipse Foundation
# 
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
# 
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0, or the Apache License, Version 2.0
# which is available at https://www.apache.org/licenses/LICENSE-2.0.
#
# SPDX-License-Identifier: EPL-2.0 OR Apache-2.0
#
# Contributors: Gabriele Baldoni, ADLINK Technology Inc. - Initial implementation and API


from enum import Enum


class State(Enum):

    """
    States of entities
    """

    ERROR = -1
    UNDEFINED = 0
    DEFINED = 1
    CONFIGURED = 3
    RUNNING = 4
    PAUSED = 5
    SCALING = 6
    MIGRATING = 7
    # Migration concurrent states
    TAKING_OFF = 8
    LANDING = 9
