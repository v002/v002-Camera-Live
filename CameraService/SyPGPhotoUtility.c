//
//  SyPGPhotoUtility.c
//  CameraService
//
//  Created by Tom Butterworth on 29/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#include "SyPGPhotoUtility.h"
#include <assert.h>
#include <string.h>

static int
camera_lookup_widget(CameraWidget*widget, const char *key, CameraWidget **child)
{
    int ret = gp_widget_get_child_by_name (widget, key, child);
    if (ret < GP_OK)
        ret = gp_widget_get_child_by_label (widget, key, child);
    return ret;
}

int
camera_get_config_value_string(Camera *camera, const char *key, char **string, GPContext *context)
{
    CameraWidget *widget = NULL, *child = NULL;
    CameraWidgetType type;
    int ret;
    char *val;

    ret = gp_camera_get_single_config (camera, key, &child, context);
    if (ret == GP_OK)
    {
        assert(child);
        widget = child;
    }
    else
    {
        ret = gp_camera_get_config (camera, &widget, context);
        if (ret < GP_OK)
        {
            return ret;
        }
        ret = camera_lookup_widget (widget, key, &child);
        if (ret < GP_OK)
        {
            goto out;
        }
    }

    /* This type check is optional, if you know what type the label
     * has already. If you are not sure, better check. */
    ret = gp_widget_get_type (child, &type);
    if (ret < GP_OK)
    {
        goto out;
    }
    switch (type) {
        case GP_WIDGET_MENU:
        case GP_WIDGET_RADIO:
        case GP_WIDGET_TEXT:
        break;
    default:
        ret = GP_ERROR_BAD_PARAMETERS;
        goto out;
    }

    /* This is the actual query call. Note that we just
     * a pointer reference to the string, not a copy... */
    ret = gp_widget_get_value (child, &val);
    if (ret < GP_OK)
    {
        goto out;
    }
    /* Create a new copy for our caller. */
    *string = strdup (val);
out:
    gp_widget_free (widget);
    return ret;
}

/*
 * This function opens a camera depending on the specified model and port.
 */
int
camera_open(Camera ** camera, const char *model, const char *port, GPContext *context,
            GPPortInfoList **portinfolist, CameraAbilitiesList **abilitieslist)
{
    int m, portIndex;
    CameraAbilities abilities;
    GPPortInfo portinfo;


    int result = gp_camera_new (camera);
    if (result < GP_OK) return result;

    if (!*abilitieslist)
    {
        /* Load all the camera drivers we have... */
        result = gp_abilities_list_new (abilitieslist);
        if (result < GP_OK) return result;
        result = gp_abilities_list_load (*abilitieslist, context);
        if (result < GP_OK) return result;
    }

    /* First lookup the model / driver */
    m = gp_abilities_list_lookup_model (*abilitieslist, model);
    if (m < GP_OK) return result;
    result = gp_abilities_list_get_abilities (*abilitieslist, m, &abilities);
    if (result < GP_OK) return result;
    result = gp_camera_set_abilities (*camera, abilities);
    if (result < GP_OK) return result;

    if (!*portinfolist)
    {
        /* Load all the port drivers we have... */
        result = gp_port_info_list_new (portinfolist);
        if (result < GP_OK) return result;
        result = gp_port_info_list_load (*portinfolist);
        if (result < 0) return result;
    }

    /* Then associate the camera with the specified port */
    portIndex = gp_port_info_list_lookup_path (*portinfolist, port);
    if (portIndex < GP_OK) return portIndex;
    result = gp_port_info_list_get_info (*portinfolist, portIndex, &portinfo);
    if (result < GP_OK) return result;
    result = gp_camera_set_port_info (*camera, portinfo);
    if (result < GP_OK) return result;
    result = gp_camera_init(*camera, context);

    return result;
}

/*
 * This enables/disables the specific canon capture mode.
 *
 * For non canons this is not required, and will just return
 * with an error (but without negative effects).
 */
int
canon_enable_capture(Camera *camera, int onoff, GPContext *context)
{
    CameraWidget        *widget = NULL;
    CameraWidgetType    type;
    int            ret;

    ret = gp_camera_get_single_config (camera, "capture", &widget, context);
    if (ret < GP_OK)
    {
        return ret;
    }

    ret = gp_widget_get_type (widget, &type);
    if (ret < GP_OK)
    {
        goto out;
    }
    switch (type)
    {
        case GP_WIDGET_TOGGLE:
        break;
    default:
        ret = GP_ERROR_BAD_PARAMETERS;
        goto out;
    }
    /* Now set the toggle to the wanted value */
    ret = gp_widget_set_value (widget, &onoff);
    if (ret < GP_OK)
    {
        goto out;
    }
    /* OK */
    ret = gp_camera_set_single_config (camera, "capture", widget, context);
    if (ret < GP_OK)
    {
        return ret;
    }
out:
    gp_widget_free (widget);
    return ret;
}
