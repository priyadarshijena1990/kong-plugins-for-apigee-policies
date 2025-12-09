<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes"/>

  <!-- Example: Define parameters that can be passed from the Kong plugin -->
  <xsl:param name="input_param_name"/>
  <xsl:param name="static_param_name"/>

  <xsl:template match="/">
    <transformed_data>
      <message>This is a default transformation.</message>
      <original_root_element>
        <xsl:value-of select="name(/*)"/>
      </original_root_element>
      <params>
        <input_param_value><xsl:value-of select="$input_param_name"/></input_param_value>
        <static_param_value><xsl:value-of select="$static_param_name"/></static_param_value>
      </params>
      <original_content>
        <xsl:copy-of select="."/>
      </original_content>
    </transformed_data>
  </xsl:template>

</xsl:stylesheet>
