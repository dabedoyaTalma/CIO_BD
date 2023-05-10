/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_DockOperator]    Script Date: 10/05/2023 8:46:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Juan Camilo Zuluaga
-- Create date: 2019-10-15
-- Description:	Function for Businees Rules "add dock operator"
-- Change History:
--   2019-10-15 Juan Camilo Zuluaga: Function created

-- SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_DockOperator] (12254, 3, 9, '2019-07-26')
-- =============================================
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_DockOperator](
	@HeaderServiceId INT,
	@AirportId INT,
	--@p_fk_id_tipo_srv INT
	@CompanyId INT,
	--@p_fk_id_facturar_a INT
	@DateService DATE
)
RETURNS @T_Result TABLE(ROW INT IDENTITY, StartDate DATETIME, EndDate DATETIME, IsAdditionalService BIT, AdditionalQuantity INT, AdditionalService VARCHAR(150))
AS
BEGIN
	DECLARE @T_TMP_DETALLE_SRV AS CIOReglaNegocio.ServiceDetailType --TIPO DEFINIDO
	INSERT	@T_TMP_DETALLE_SRV
	SELECT	ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) fila,
			'OPERADOR DE MUELLE',
			DS.FechaInicio, 
			DS.FechaFin, 
			DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) tiempo_total, 
			ISNULL(DS.cantidad, 1) cantidad
	FROM	CIOServicios.DetalleServicio DS
	WHERE	DS.Activo = 1 AND
			DS.TipoActividadId = 298 AND --OPERADOR DE MUELLE
			DS.EncabezadoServicioId = @HeaderServiceId


	IF (SELECT SUM(cantidad) FROM @T_TMP_DETALLE_SRV) = 0 RETURN
			
	IF(@CompanyId IN (9, 56)) --COPA     
	BEGIN
		IF (@AirportId = 11 AND @DateService >= '2019-07-01') --BGA A PARTIR DEL 2019-07-01 LO TIENE INCLUIDO
		BEGIN
			INSERT @T_Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 1)
			RETURN
		END

		INSERT @T_Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@T_TMP_DETALLE_SRV, 0)
		RETURN
	END

	RETURN
END

